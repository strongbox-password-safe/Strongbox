//
//  SubscriptionManager.m
//  Strongbox-iOS
//
//  Created by Mark on 04/02/2019.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import "ProUpgradeIAPManager.h"
#import "NSArray+Extensions.h"
#import "Utils.h"
#import "RMStore.h"
#import "RMStoreAppReceiptVerifier.h"
#import "RMAppReceipt.h"
#import "Model.h"
#import "CrossPlatform.h"
#import "NSDate+Extensions.h"
#import "Constants.h"

#if TARGET_OS_IOS
#import "CustomizationManager.h"
#elif TARGET_OS_MAC
#import "MacCustomizationManager.h"
#endif

#if defined(SUBSCRIPTIONS)

#import "Strongbox-Swift.h"
#endif

#import "SBLog.h"

static NSString* const kIapProId  = @"com.markmcguill.strongbox.pro";
static NSString* const kMonthly   = @"com.strongbox.markmcguill.upgrade.pro.monthly";
static NSString* const kYearly    = @"com.strongbox.markmcguill.upgrade.pro.yearly";

@interface ProUpgradeIAPManager ()

@property (nonatomic) UpgradeManagerState readyState;
@property (nonatomic, strong) NSDictionary<NSString*, SKProduct *> *products;
@property (nonatomic) RMStoreAppReceiptVerifier* receiptVerifier;

@property (readonly) id<ApplicationPreferences> preferences;
@property (readonly, nullable) SKProduct* lifeTimeProduct;
@property (readonly) BOOL isVerifiedReceipt;

@end

@implementation ProUpgradeIAPManager

+ (instancetype)sharedInstance {
    static ProUpgradeIAPManager *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[ProUpgradeIAPManager alloc] init];
    });
    return sharedInstance;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)productsDidLoad:(NSNotification *)notification {
    slog(@"✅ Products loaded notification received");
    self.readyState = kReady;

    if (self.productsAvailableNotify) {
        self.productsAvailableNotify();
    }
}

- (id<ApplicationPreferences>)preferences {
    return CrossPlatformDependencies.defaults.applicationPreferences;
}

- (UpgradeManagerState)state {
    return self.readyState;
}

- (BOOL)isVerifiedReceipt {
#if defined(SUBSCRIPTIONS)
    return [RCStrongboxBridge isReceiptVerified];
#else
#ifdef DEBUG
    slog(@"⚠️⚠️⚠️ DEBUG Faking Verified Receipt DEBUG 🔴");
    return YES;
#else
    RMStoreAppReceiptVerifier *verificator = [[RMStoreAppReceiptVerifier alloc] init];
    return [verificator verifyAppReceipt];
#endif
#endif
}

- (void)initialize {
#if defined(SUBSCRIPTIONS)
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(productsDidLoad:)
                                                 name:@"ProductsLoadedNotification"
                                               object:nil];

    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(subscriptionStatusChanged:)
                                                 name:@"SubscriptionStatusChangedNotification"
                                               object:nil];

    slog(@"🐱 Initialising RevenueCat");

    
    [RCStrongboxBridge setOnFetchComplete:^{
        [[NSNotificationCenter defaultCenter] postNotificationName:kRevenueCatFetchCompleteNotification object:nil];
    }];
    
    [RCStrongboxBridge initializeRevenueCat];

    
    [RCStrongboxBridge setOnSubscriptionUpdated:^(BOOL pro) {
        [self didUpdateSubscription:pro];
    }];

    
    [RCStrongboxBridge loadAppStoreProducts];
    
    
    [self setIsFreeTrialAvailable:YES];
    
    
   
#else
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0L), ^{
        slog(@"✅ ProUpgradeIAPManager::initialize - Loading Products and Checking Receipt for entitlements");
        [self loadAppStoreProducts];
        if (self.isVerifiedReceipt) {
            slog(@"App Receipt looks ok... checking for Valid Pro IAP purchases...");
            [self checkVerifiedReceiptIsEntitledToPro:NO];
        } else {
            slog(@"Startup receipt check failed...");
        }
        [self listenForPurchases];
    });
#endif
}

- (void)restorePrevious:(RestoreCompletionBlock)completion {
#if defined(SUBSCRIPTIONS)
    [RCStrongboxBridge restorePurchasesWithCompletion:completion];
#else
    [[RMStore defaultStore] restoreTransactionsOnSuccess:^(NSArray *transactions) {
        slog(@"Restore Done Successfully: [%@]", transactions);
        for (SKPaymentTransaction* pt in transactions) {
            slog(@"Restored: %@-%@", pt.originalTransaction.payment.productIdentifier, pt.originalTransaction.transactionDate);
        }
        [self checkReceiptForTrialAndProEntitlements];
        if (completion) {
            completion(nil);
        }
    } failure:^(NSError *error) {
        if (completion) {
            completion(error);
        }
    }];
#endif
}

- (void)purchaseAndCheckReceipts:(SKProduct *)product completion:(PurchaseCompletionBlock)completion {
#if defined(SUBSCRIPTIONS)
    [RCStrongboxBridge purchaseProduct:product completion:completion];
#else
    if (![SKPaymentQueue canMakePayments]) {
        completion([Utils createNSError:NSLocalizedString(@"upgrade_mgr_purchases_are_disabled", @"Purchases are disabled on your device.") errorCode:-1]);
        return;
    }

    [[RMStore defaultStore] addPayment:product.productIdentifier
                               success:^(SKPaymentTransaction *transaction) {
        slog(@"Product purchased: [%@]", transaction);
        [self checkReceiptForTrialAndProEntitlements];
        completion(nil);
    } failure:^(SKPaymentTransaction *transaction, NSError *error) {
        slog(@"Something went wrong: [%@] error = [%@]", transaction, error);
        completion(error);
    }];
#endif
}

#pragma mark - Legacy Methods (Forwarded in Subscription Builds)

- (void)listenForPurchases {
#if defined(SUBSCRIPTIONS)
    [RCStrongboxBridge listenForPurchases];
#else
    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(onPurchaseNotification)
                                               name:RMSKPaymentTransactionFinished
                                             object:nil];
#endif
}

- (void)onPurchaseNotification {
#if defined(SUBSCRIPTIONS)
    [RCStrongboxBridge onPurchaseNotification];
#else
    slog(@"♻️ onPurchaseNotification");
    [self checkReceiptForTrialAndProEntitlements];
#endif
}

- (NSDate*)currentSubscriptionRenewalOrExpiry {
#if defined(SUBSCRIPTIONS)
    return [RCStrongboxBridge currentSubscriptionRenewalOrExpiry];
#else
    if (self.hasActiveYearlySubscription) {
        return [RMAppReceipt.bundleReceipt expirationDateFor:kYearly];
    }
    else if (self.hasActiveMonthlySubscription) {
        return [RMAppReceipt.bundleReceipt expirationDateFor:kMonthly];
    }
    return nil;
#endif
}

- (void)performScheduledProEntitlementsCheckIfAppropriate {
#if defined(SUBSCRIPTIONS)
    [RCStrongboxBridge performScheduledProEntitlementsCheckIfAppropriate];
#else
    slog(@"🐞 performScheduledProEntitlementsCheckIfAppropriate");

#if TARGET_OS_IOS
    if ( CustomizationManager.isAProBundle ) {
#elif TARGET_OS_MAC
    if ( MacCustomizationManager.isAProBundle || MacCustomizationManager.isSetapp ) {
#endif
        slog(@"🐞 Pro edition - the bundle itself is the entitlement, no receipt check required.");
        return;
    }

    if (self.preferences.lastEntitlementCheckAttempt != nil) {
        NSCalendar *gregorian = [[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian];
        NSDateComponents *components = [gregorian components:NSCalendarUnitDay
                                                    fromDate:self.preferences.lastEntitlementCheckAttempt
                                                      toDate:[NSDate date]
                                                     options:0];
        NSInteger days = [components day];
        slog(@"🐞 %ld days since last entitlement check... [%@]", (long)days, self.preferences.lastEntitlementCheckAttempt);
        if (days == 0) {
            slog(@"🐞 Already checked entitlements today... not rechecking...");
            return;
        }
        if (self.preferences.numberOfEntitlementCheckFails == 0 && days < 3) {
            slog(@"🐞 We had a successful check recently, not rechecking...");
            return;
        }
        else {
            slog(@"🐞 Rechecking since numberOfFails = %lu and days = %ld...", (unsigned long)self.preferences.numberOfEntitlementCheckFails, (long)days);
        }
    }
    slog(@"🐞 Performing Scheduled Check of Entitlements...");

    
    
    
    
    [self checkReceiptForTrialAndProEntitlements];
#endif
}

- (void)checkReceiptForTrialAndProEntitlements {
#if defined(SUBSCRIPTIONS)
    [RCStrongboxBridge checkReceiptForTrialAndProEntitlements:NO completion:nil];
#else
    [self checkReceiptForTrialAndProEntitlements:NO completion:nil];
#endif
}

- (void)checkReceiptForTrialAndProEntitlements:(BOOL)userInitiated completion:(void(^)(void))completion {
#if defined(SUBSCRIPTIONS)
    [RCStrongboxBridge checkReceiptForTrialAndProEntitlements:userInitiated completion:completion];
#else
    self.preferences.lastEntitlementCheckAttempt = [NSDate date];

    if (self.isVerifiedReceipt) {
        slog(@"Receipt Valid... checking for Valid Pro IAP purchases...");
        [self checkVerifiedReceiptIsEntitledToPro:userInitiated];
    } else {
        self.preferences.numberOfEntitlementCheckFails++;
        slog(@"Number of Entitlement Check Fails Now = %lu", (unsigned long)self.preferences.numberOfEntitlementCheckFails);
    }

    if (completion) {
        completion();
    }
#endif
}

- (void)refreshReceiptAndCheckForProEntitlements:(void(^)(void))completion {
#if defined(SUBSCRIPTIONS)
    [RCStrongboxBridge refreshReceiptAndCheckForProEntitlements:completion];
#else
    [[RMStore defaultStore] refreshReceiptOnSuccess:^{
        if (self.isVerifiedReceipt) {
            slog(@"App Receipt looks ok... checking for Valid Pro IAP purchases...");
            [self checkVerifiedReceiptIsEntitledToPro:NO];
            if (completion) { completion(); }
        } else {
            slog(@"Receipt not good even after refresh");
            if (!NO) {  
                self.preferences.numberOfEntitlementCheckFails++;
            }
            if (completion) { completion(); }
        }
    } failure:^(NSError *error) {
        slog(@"Refresh Receipt - Error [%@]", error);
        if (!NO) {
            self.preferences.numberOfEntitlementCheckFails++;
        }
        if (completion) { completion(); }
    }];
#endif
}

- (void)checkVerifiedReceiptIsEntitledToPro:(BOOL)userInitiated {
#if defined(SUBSCRIPTIONS)
    [RCStrongboxBridge checkVerifiedReceiptIsEntitledToPro:userInitiated];
#else
    if (!userInitiated) {
        self.preferences.numberOfEntitlementCheckFails = 0;
    }
#if TARGET_OS_IOS
    if (CustomizationManager.isAProBundle) {
#elif TARGET_OS_MAC
    if (MacCustomizationManager.isAProBundle || MacCustomizationManager.isSetapp) {
#endif
        slog(@"Upgrading App to Pro as Receipt is Good and this is a Pro edition...");
        [self.preferences setPro:YES];
        self.preferences.appHasBeenDowngradedToFreeEdition = NO;
    }
    else if ([self receiptHasProEntitlements]) {
        slog(@"Upgrading App to Pro as Entitlement found in Receipt...");
        [self.preferences setPro:YES];
        self.preferences.appHasBeenDowngradedToFreeEdition = NO;
    }
    else {
        if (self.preferences.isPro) {
            if (!userInitiated) {
                slog(@"PRO Entitlement NOT found in valid Receipt, incrementing fail count...");
                self.preferences.numberOfEntitlementCheckFails++;
            } else {
                slog(@"PRO Entitlement NOT found in valid Receipt");
            }
        }
        else {
            slog(@"App Pro Entitlement not found in Receipt... leaving downgraded...");
        }
    }
#endif
}

- (BOOL)receiptHasProEntitlements {
#if defined(SUBSCRIPTIONS)
    return [RCStrongboxBridge receiptHasProEntitlements];
#else
    RMAppReceipt* receipt = [RMAppReceipt bundleReceipt];
    if (receipt == nil) {
        slog(@"🔴 NIL Bundle Receipt");
        return NO;
    }
    BOOL lifetime = [receipt containsInAppPurchaseOfProductIdentifier:kIapProId];
    NSDate* now = [NSDate date];
    BOOL monthly = [receipt containsActiveAutoRenewableSubscriptionOfProductIdentifier:kMonthly forDate:now];
    BOOL yearly  = [receipt containsActiveAutoRenewableSubscriptionOfProductIdentifier:kYearly forDate:now];
    slog(@"Found Lifetime=%d, Monthly=%d, Yearly=%d", lifetime, monthly, yearly);
    return lifetime || monthly || yearly;
#endif
}

- (void)loadAppStoreProducts {
#if defined(SUBSCRIPTIONS)
    [RCStrongboxBridge loadAppStoreProducts];
#else
    self.readyState = kWaitingOnAppStoreProducts;
    self.products = @{};
    NSSet *productsSet = [NSSet setWithArray:@[kIapProId, kMonthly, kYearly]];

    [[RMStore defaultStore] requestProducts:productsSet
                                   success:^(NSArray *products, NSArray *invalidProductIdentifiers) {
        self.products = [NSMutableDictionary dictionary];
        if (products) {
            for (SKProduct *validProduct in products) {
                slog(@"Got App Store Product [%@-%@]", validProduct.productIdentifier, validProduct.price);
                [self.products setValue:validProduct forKey:validProduct.productIdentifier];
            }
        }
        self.readyState = kReady;
        if (self.productsAvailableNotify) {
            self.productsAvailableNotify();
        }
    } failure:^(NSError *error) {
        slog(@"Error Retrieving IAP Products: [%@]", error);
        self.readyState = kCouldNotGetProducts;
        if (self.productsAvailableNotify) {
            self.productsAvailableNotify();
        }
    }];
#endif
}

- (NSDictionary<NSString *,SKProduct *> *)availableProducts {
#if defined(SUBSCRIPTIONS)
    return [RCStrongboxBridge availableProducts];
#else
    return (self.readyState == kReady) ? [self.products copy] : @{};
#endif
}

- (BOOL)hasPurchasedLifeTime {
#if defined(SUBSCRIPTIONS)
    return [RCStrongboxBridge hasPurchasedLifeTime];
#else
    if (RMAppReceipt.bundleReceipt == nil) {
        slog(@"bundleReceipt = nil");
        return NO;
    }
    RMAppReceiptIAP *iap = [RMAppReceipt.bundleReceipt.inAppPurchases firstOrDefault:^BOOL(RMAppReceiptIAP *iap) {
        return [iap.productIdentifier isEqualToString:kIapProId];
    }];
    return iap != nil;
#endif
}

- (BOOL)isLegacyLifetimeIAPPro {
#if defined(SUBSCRIPTIONS)
    return [RCStrongboxBridge isLegacyLifetimeIAPPro];
#else
    return [self hasPurchasedLifeTime];
#endif
}

- (BOOL)hasSetapp {
#if TARGET_OS_MAC && SETAPP
    return YES;
#elif defined(SUBSCRIPTIONS) && TARGET_OS_IOS
    return [RCStrongboxBridge setappSubscription];
#else
    return NO;
#endif
}

- (BOOL)hasActiveYearlySubscription {
#if defined(SUBSCRIPTIONS)
    return [RCStrongboxBridge hasActiveYearlySubscription];
#else
    NSDate* now = [NSDate date];
    return [[RMAppReceipt bundleReceipt] containsActiveAutoRenewableSubscriptionOfProductIdentifier:kYearly forDate:now];
#endif
}

- (BOOL)hasActiveMonthlySubscription {
#if defined(SUBSCRIPTIONS)
    return [RCStrongboxBridge hasActiveMonthlySubscription];
#else
    NSDate* now = [NSDate date];
    return [[RMAppReceipt bundleReceipt] containsActiveAutoRenewableSubscriptionOfProductIdentifier:kMonthly forDate:now];
#endif
}

- (SKProduct *)lifetimeProduct {
#if defined(SUBSCRIPTIONS)
    return [RCStrongboxBridge lifeTimeProduct];
#else
    return self.availableProducts[kMonthly];
#endif
}

- (SKProduct *)monthlyProduct {
#if defined(SUBSCRIPTIONS)
    return [RCStrongboxBridge monthlyProduct];
#else
    return self.availableProducts[kMonthly];
#endif
}

- (SKProduct *)yearlyProduct {
#if defined(SUBSCRIPTIONS)
    return [RCStrongboxBridge yearlyProduct];
#else
    return self.availableProducts[kYearly];
#endif
}

- (nullable NSString *)freeTrialDurationText {
#if defined(SUBSCRIPTIONS)
    
    
    return [RCStrongboxBridge freeTrialDurationText];
#else
    
    return [self trialDurationTextForProduct:self.yearlyProduct];
#endif
}

- (nullable NSString *)trialDurationTextForProduct:(SKProduct*)product {
    if ( !product ) {
        return nil;
    }

    SKProductDiscount* intro = product.introductoryPrice;
    if ( !intro ) {
        return nil;
    }

    if ( intro.paymentMode != SKProductDiscountPaymentModeFreeTrial &&
         ![intro.price isEqual:NSDecimalNumber.zero] ) {
        return nil;
    }

    SKProductSubscriptionPeriod* period = intro.subscriptionPeriod;
    if ( !period ) {
        return nil;
    }

    return [ProUpgradeIAPManager localizedDurationWithUnit:period.unit numberOfUnits:period.numberOfUnits];
}

+ (nullable NSString *)localizedDurationWithUnit:(SKProductPeriodUnit)unit numberOfUnits:(NSInteger)numberOfUnits {
    if ( numberOfUnits <= 0 ) {
        return nil;
    }

    NSDateComponents* components = [[NSDateComponents alloc] init];
    NSCalendarUnit allowedUnit = 0;

    switch ( unit ) {
        case SKProductPeriodUnitDay:
            components.day = numberOfUnits;
            allowedUnit = NSCalendarUnitDay;
            break;
        case SKProductPeriodUnitWeek:
            components.weekOfMonth = numberOfUnits;
            allowedUnit = NSCalendarUnitWeekOfMonth;
            break;
        case SKProductPeriodUnitMonth:
            components.month = numberOfUnits;
            allowedUnit = NSCalendarUnitMonth;
            break;
        case SKProductPeriodUnitYear:
            components.year = numberOfUnits;
            allowedUnit = NSCalendarUnitYear;
            break;
        default:
            return nil;
    }

    NSDateComponentsFormatter* formatter = [[NSDateComponentsFormatter alloc] init];
    formatter.allowedUnits = allowedUnit;
    formatter.unitsStyle = NSDateComponentsFormatterUnitsStyleFull;
    formatter.maximumUnitCount = 1;

    return [formatter stringFromDateComponents:components];
}

- (SKProduct *)lifeTimeProduct {
#if defined(SUBSCRIPTIONS)
    return [RCStrongboxBridge lifeTimeProduct];
#else
    return self.availableProducts[kIapProId];
#endif
}

-(void)checkTrialEligibility {
#if defined(SUBSCRIPTIONS)
    [RCStrongboxBridge isFreeTrialAvailableWithCompletionHandler:^(BOOL trialEligible) {
        [self setIsFreeTrialAvailable:trialEligible];
    }];
#endif
}

#pragma mark - Subscription Updates Handler

- (void)didUpdateSubscription:(BOOL)pro {
    #if TARGET_OS_MAC && !TARGET_OS_IOS
    BOOL isPro = pro || MacCustomizationManager.isAProBundle || MacCustomizationManager.isSetapp;
    slog(@"🔄 SubscriptionUpdate - didUpdateSubscription: isPro = %@ isProBundle = %@", pro ? @"YES" : @"NO", MacCustomizationManager.isAProBundle ? @"YES" : @"NO");
    #else
    BOOL isPro = pro || CustomizationManager.isAProBundle;
    slog(@"🔄 SubscriptionUpdate - didUpdateSubscription: isPro = %@ isProBundle = %@", pro ? @"YES" : @"NO", CustomizationManager.isAProBundle ? @"YES" : @"NO");
    #endif

    [self.preferences setPro:isPro];

    if (isPro) {
        self.preferences.numberOfEntitlementCheckFails = 0;
        self.preferences.appHasBeenDowngradedToFreeEdition = NO;
    }

    
    if (self.productsAvailableNotify) {
        self.productsAvailableNotify();
    }
}

#pragma mark - Subscription Status Notification Handler

- (void)subscriptionStatusChanged:(NSNotification *)notification {
    #if TARGET_OS_MAC && !TARGET_OS_IOS
    BOOL isPro = [notification.userInfo[@"isPro"] boolValue] || MacCustomizationManager.isAProBundle || MacCustomizationManager.isSetapp;
    #else
    BOOL isPro = [notification.userInfo[@"isPro"] boolValue] || CustomizationManager.isAProBundle;
    #endif

    slog(@"🔄 Subscription status changed notification received: isPro = %@", isPro ? @"YES" : @"NO");

    [self didUpdateSubscription:isPro];
}

@end
