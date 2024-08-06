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

#if TARGET_OS_IPHONE
#import "CustomizationManager.h"
#elif TARGET_OS_MAC
#import "MacCustomizationManager.h"
#endif

static NSString* const kIapProId =  @"com.markmcguill.strongbox.pro";
static NSString* const kMonthly =  @"com.strongbox.markmcguill.upgrade.pro.monthly";
static NSString* const kYearly =  @"com.strongbox.markmcguill.upgrade.pro.yearly";

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

- (id<ApplicationPreferences>)preferences {
    return CrossPlatformDependencies.defaults.applicationPreferences;
}

-(UpgradeManagerState)state {
    return self.readyState;
}

- (BOOL)isVerifiedReceipt {
#ifdef DEBUG
    slog(@"⚠️⚠️⚠️⚠️⚠️⚠️ DEBUG Faking Verified Receipt DEBUG 🔴🔴🔴🔴🔴🔴🔴");
    return YES;
#else
    RMStoreAppReceiptVerifier *verificator = [[RMStoreAppReceiptVerifier alloc] init];
    return [verificator verifyAppReceipt];
#endif
}

- (void)initialize {    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0L), ^{
        slog(@"✅ ProUpgradeIAPManager::initialize - Loading Products and Checking Receipt for entitlements");
        
        [self loadAppStoreProducts];
        
        
        
        if ( self.isVerifiedReceipt ) {
            slog(@"App Receipt looks ok... checking for Valid Pro IAP purchases...");
            [self checkVerifiedReceiptIsEntitledToPro:NO];
        }
        else {
            
            slog(@"Startup receipt check failed...");
        }
        
        [self listenForPurchases];
    });
}

- (void)listenForPurchases {
    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(onPurchaseNotification)
                                               name:RMSKPaymentTransactionFinished
                                             object:nil];
}

- (void)onPurchaseNotification {
    slog(@"♻️♻️♻️♻️♻️♻️♻️♻️♻️♻️♻️ onPurchaseNotification ♻️♻️♻️♻️♻️♻️♻️♻️♻️♻️♻️♻️♻️♻️♻️");
    
    [self checkReceiptForTrialAndProEntitlements];
}

- (NSDate*)currentSubscriptionRenewalOrExpiry {
    if ( self.hasActiveYearlySubscription ) {
        return [RMAppReceipt.bundleReceipt expirationDateFor:kYearly];
    }
    else if ( self.hasActiveMonthlySubscription ) {
        return [RMAppReceipt.bundleReceipt expirationDateFor:kMonthly];
    }
    return nil;
}

- (void)performScheduledProEntitlementsCheckIfAppropriate {
    slog(@"🐞 performScheduledProEntitlementsCheckIfAppropriate");
    
    if ( self.preferences.lastEntitlementCheckAttempt != nil ) {
        NSCalendar *gregorian = [[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian];
        
        NSDateComponents *components = [gregorian components:NSCalendarUnitDay
                                                    fromDate:self.preferences.lastEntitlementCheckAttempt
                                                      toDate:[NSDate date]
                                                     options:0];
        
        NSInteger days = [components day];
        
        slog(@"🐞 %ld days since last entitlement check... [%@]", (long)days, self.preferences.lastEntitlementCheckAttempt);
        
        if ( days == 0 ) { 
            slog(@"🐞 Already checked entitlements today... not rechecking...");
            return;
        }
        
        if ( self.preferences.numberOfEntitlementCheckFails == 0 && days < 3 ) {
            
            
            slog(@"🐞 We had a successful check recently, not rechecking...");
            return;
        }
        else {
            slog(@"🐞 Rechecking since numberOfFails = %lu and days = %ld...", (unsigned long)self.preferences.numberOfEntitlementCheckFails, (long)days);
        }
    }
    
    slog(@"🐞 Performing Scheduled Check of Entitlements...");
     
    if ( self.preferences.numberOfEntitlementCheckFails < 2 ) {
        [self checkReceiptForTrialAndProEntitlements];
    }
    else {
        self.preferences.appHasBeenDowngradedToFreeEdition = YES;
        self.preferences.hasPromptedThatAppHasBeenDowngradedToFreeEdition = NO;
        self.preferences.numberOfEntitlementCheckFails = 0; 
        [self.preferences setPro:NO];
    }
}

- (void)checkReceiptForTrialAndProEntitlements {
    [self checkReceiptForTrialAndProEntitlements:NO completion:nil];
}

- (void)refreshReceiptAndCheckForProEntitlements:(void(^)(void))completion {
    [self checkReceiptForTrialAndProEntitlements:YES completion:completion];
}

- (void)checkReceiptForTrialAndProEntitlements:(BOOL)userInitiated completion:(void(^_Nullable)(void))completion { 
    
    slog(@"🚀 checkReceiptForTrialAndProEntitlements... ");
    
    if ( !userInitiated ) {
        self.preferences.lastEntitlementCheckAttempt = [NSDate date];
    }

    if ( self.isVerifiedReceipt ) {
        slog(@"App Receipt looks ok... checking for Valid Pro IAP purchases...");
        [self checkVerifiedReceiptIsEntitledToPro:userInitiated];
        if (completion) {
            completion();
        }
    }
    else {
        slog(@"Receipt Not Good... Refreshing...");

        [[RMStore defaultStore] refreshReceiptOnSuccess:^{
            if ( self.isVerifiedReceipt ) {
                slog(@"App Receipt looks ok... checking for Valid Pro IAP purchases...");
                [self checkVerifiedReceiptIsEntitledToPro:userInitiated];
                if (completion) completion();
            }
            else {
                slog(@"Receipt not good even after refresh");
                if ( !userInitiated ) {
                    self.preferences.numberOfEntitlementCheckFails++;
                }
                if (completion) completion();
            }
        } failure:^(NSError *error) {
            slog(@"Refresh Receipt - Error [%@]", error);
            if ( !userInitiated ) {
                self.preferences.numberOfEntitlementCheckFails++;
            }
            if (completion) completion();
        }];
    }
}

- (void)checkVerifiedReceiptIsEntitledToPro:(BOOL)userInitiated { 
    if ( !userInitiated ) {
        self.preferences.numberOfEntitlementCheckFails = 0;
    }
    
#if TARGET_OS_IPHONE
    if ( CustomizationManager.isAProBundle ) {
#elif TARGET_OS_MAC
    if ( MacCustomizationManager.isAProBundle ) {
#endif
        slog(@"Upgrading App to Pro as Receipt is Good and this is a Pro edition...");
        [self.preferences setPro:YES];
        self.preferences.appHasBeenDowngradedToFreeEdition = NO;
    }
    else if ( [self receiptHasProEntitlements] ) {
        slog(@"Upgrading App to Pro as Entitlement found in Receipt...");
        [self.preferences setPro:YES];
        self.preferences.appHasBeenDowngradedToFreeEdition = NO;
    }
    else {
        if ( self.preferences.isPro ) {

                                  
            if ( !userInitiated ) {
                slog(@"PRO Entitlement NOT found in valid Receipt, incrementing fail count to allow for grace period but very likely app not entitled to Pro...");
                self.preferences.numberOfEntitlementCheckFails++;
            }
            else {
                slog(@"PRO Entitlement NOT found in valid Receipt");
            }
            
            



        }
        else {
            slog(@"App Pro Entitlement not found in Receipt... leaving downgraded...");
        }
    }
}

- (BOOL)receiptHasProEntitlements {
    RMAppReceipt* receipt = [RMAppReceipt bundleReceipt];
    
    if ( receipt == nil ) {
        slog(@"🔴 NIL Bundle Receipt");
        return NO;
    }
    
    BOOL lifetime = [receipt containsInAppPurchaseOfProductIdentifier:kIapProId]; 
    
    NSDate* now = [NSDate date];
    BOOL monthly = [receipt containsActiveAutoRenewableSubscriptionOfProductIdentifier:kMonthly forDate:now];
    BOOL yearly = [receipt containsActiveAutoRenewableSubscriptionOfProductIdentifier:kYearly forDate:now];
    
    slog(@"Found Lifetime=%d, Monthly=%d, Yearly=%d", lifetime, monthly, yearly);
    
    return lifetime || monthly || yearly;
}

- (void)loadAppStoreProducts {
    self.readyState = kWaitingOnAppStoreProducts;
    self.products = @{};

    NSSet *products = [NSSet setWithArray:@[kIapProId, kMonthly, kYearly]];
    
    [[RMStore defaultStore] requestProducts:products success:^(NSArray *products, NSArray *invalidProductIdentifiers) {
        self.products = [NSMutableDictionary dictionary];
        if (products) {
            for (SKProduct *validProduct in products) {
                slog(@"Got App Store Product [%@-%@]",
                      validProduct.productIdentifier,
                      validProduct.price);
                [self.products setValue:validProduct forKey:validProduct.productIdentifier];
            }
        }
        self.readyState = kReady;
        if(self.productsAvailableNotify) {
            self.productsAvailableNotify();
        }
    } failure:^(NSError *error) {
        slog(@"Error Retrieving IAP Products: [%@]", error);
        self.readyState = kCouldNotGetProducts;
        if(self.productsAvailableNotify) {
            self.productsAvailableNotify();
        }
    }];
}

- (NSDictionary<NSString *,SKProduct *> *)availableProducts {
    return self.readyState == kReady ? [self.products copy] : @{};
}

- (void)restorePrevious:(RestoreCompletionBlock)completion {
    [RMStore.defaultStore restoreTransactionsOnSuccess:^(NSArray *transactions) {
        slog(@"Restore Done Successfully: [%@]", transactions);

        for (SKPaymentTransaction* pt in transactions) {
            slog(@"Restored: %@-%@", pt.originalTransaction.payment.productIdentifier, pt.originalTransaction.transactionDate);
        }
        
        [self checkReceiptForTrialAndProEntitlements];
        
        if ( completion ) {
            completion(nil);
        }
    } failure:^(NSError *error) {
        if ( completion ) {
            completion(error);
        }
    }];
}

- (void)purchaseAndCheckReceipts:(SKProduct *)product completion:(PurchaseCompletionBlock)completion {
    if(![SKPaymentQueue canMakePayments]) {
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
}

- (BOOL)hasPurchasedLifeTime {
    if (RMAppReceipt.bundleReceipt == nil) {
        slog(@"bundleReceipt = nil");
        return NO;
    }

    RMAppReceiptIAP *iap = [RMAppReceipt.bundleReceipt.inAppPurchases firstOrDefault:^BOOL(RMAppReceiptIAP *iap) {
        return [iap.productIdentifier isEqualToString:kIapProId];
    }];
    
    return iap != nil;
}

- (BOOL)isLegacyLifetimeIAPPro {
    return self.hasPurchasedLifeTime;
}

- (BOOL)hasActiveYearlySubscription {
    NSDate* now = [NSDate date];
    return [[RMAppReceipt bundleReceipt] containsActiveAutoRenewableSubscriptionOfProductIdentifier:kYearly forDate:now];
}

- (BOOL)hasActiveMonthlySubscription {
    NSDate* now = [NSDate date];
    return [[RMAppReceipt bundleReceipt] containsActiveAutoRenewableSubscriptionOfProductIdentifier:kMonthly forDate:now];
}



- (SKProduct *)monthlyProduct {
    return self.availableProducts[kMonthly];
}

- (SKProduct *)yearlyProduct {
    return self.availableProducts[kYearly];
}

- (SKProduct *)lifeTimeProduct {
    return self.availableProducts[kIapProId];
}

- (BOOL)isFreeTrialAvailable {
    SKProduct* product = self.yearlyProduct;
    SKProductDiscount* introPrice = product ? product.introductoryPrice : nil;
    
    BOOL ret = (introPrice != nil) && [introPrice.price isEqual:NSDecimalNumber.zero];
    
    return ret;
}
    
@end
