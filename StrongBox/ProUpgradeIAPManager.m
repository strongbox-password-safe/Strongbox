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
#import "Alerts.h"
#import "AppPreferences.h"
#import "Model.h"
#import "CustomizationManager.h"

static NSString* const kIapProId =  @"com.markmcguill.strongbox.pro";
static NSString* const kMonthly =  @"com.strongbox.markmcguill.upgrade.pro.monthly";
static NSString* const k3Monthly =  @"com.strongbox.markmcguill.upgrade.pro.3monthly";
static NSString* const kYearly =  @"com.strongbox.markmcguill.upgrade.pro.yearly";
static NSString* const kIapFreeTrial =  @"com.markmcguill.strongbox.ios.iap.freetrial";

@interface ProUpgradeIAPManager ()

@property (nonatomic) UpgradeManagerState readyState;
@property (nonatomic, strong) NSDictionary<NSString*, SKProduct *> *products;
@property (nonatomic) RMStoreAppReceiptVerifier* receiptVerifier;

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

-(UpgradeManagerState)state {
    return self.readyState;
}

- (void)initialize {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0L), ^{
        [self loadAppStoreProducts];
        
        
        
        RMStoreAppReceiptVerifier *verificator = [[RMStoreAppReceiptVerifier alloc] init];
        if ([verificator verifyAppReceipt]) {
            NSLog(@"App Receipt looks ok... checking for Valid Pro IAP purchases...");
            [self checkVerifiedReceiptIsEntitledToPro];
        }
        else {
            
            NSLog(@"Startup receipt check failed...");
        }
    });
}

- (void)performScheduledProEntitlementsCheckIfAppropriate {
    if(AppPreferences.sharedInstance.lastEntitlementCheckAttempt != nil) {
        NSCalendar *gregorian = [[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian];
        
        NSDateComponents *components = [gregorian components:NSCalendarUnitDay
                                                    fromDate:AppPreferences.sharedInstance.lastEntitlementCheckAttempt
                                                      toDate:[NSDate date]
                                                     options:0];
        
        NSInteger days = [components day];
        
        NSLog(@"%ld days since last entitlement check... [%@]", (long)days, AppPreferences.sharedInstance.lastEntitlementCheckAttempt);
        
        if ( days == 0 ) { 
            NSLog(@"Already checked entitlements today... not rechecking...");
            return;
        }
        
        
        
        if(AppPreferences.sharedInstance.numberOfEntitlementCheckFails == 0 &&  days < 5) {
            NSLog(@"We had a successful check recently, not rechecking...");
            return;
        }
        else {
            NSLog(@"Rechecking since numberOfFails = %lu and days = %ld...", (unsigned long)AppPreferences.sharedInstance.numberOfEntitlementCheckFails, (long)days);
        }
    }

    NSLog(@"Performing Scheduled Check of Entitlements...");
    
    if ( AppPreferences.sharedInstance.numberOfEntitlementCheckFails < 10 ) {
        [self checkReceiptForTrialAndProEntitlements];
    }
    else {
        AppPreferences.sharedInstance.appHasBeenDowngradedToFreeEdition = YES;
        AppPreferences.sharedInstance.hasPromptedThatAppHasBeenDowngradedToFreeEdition = NO;
        [AppPreferences.sharedInstance setPro:NO];
    }
}

- (void)expressRefreshReceipt {
    [[RMStore defaultStore] refreshReceiptOnSuccess:^{
        NSLog(@"Receipt Refreshed OK");
    } failure:^(NSError *error) {
        NSLog(@"Erro Refreshing Receipt: [%@]", error);
    }];
}

- (void)checkReceiptForTrialAndProEntitlements { 
    AppPreferences.sharedInstance.lastEntitlementCheckAttempt = [NSDate date];
    
    RMStoreAppReceiptVerifier *verificator = [[RMStoreAppReceiptVerifier alloc] init];
    if ( [verificator verifyAppReceipt] ) {
        NSLog(@"App Receipt looks ok... checking for Valid Pro IAP purchases...");
        [self checkVerifiedReceiptIsEntitledToPro];
    }
    else {
        NSLog(@"Receipt Not Good... Refreshing...");

        [[RMStore defaultStore] refreshReceiptOnSuccess:^{
            if ([verificator verifyAppReceipt]) {
                NSLog(@"App Receipt looks ok... checking for Valid Pro IAP purchases...");
                [self checkVerifiedReceiptIsEntitledToPro];
            }
            else {
                NSLog(@"Receipt not good even after refresh");
                AppPreferences.sharedInstance.numberOfEntitlementCheckFails++;
            }
        } failure:^(NSError *error) {
            NSLog(@"Refresh Receipt - Error [%@]", error);
            AppPreferences.sharedInstance.numberOfEntitlementCheckFails++;
        }];
    }
}

- (void)checkVerifiedReceiptIsEntitledToPro {
    AppPreferences.sharedInstance.numberOfEntitlementCheckFails = 0;
    
    NSDate* freeTrialPurchaseDate = ProUpgradeIAPManager.sharedInstance.freeTrialPurchaseDate;
    if ( freeTrialPurchaseDate && !AppPreferences.sharedInstance.hasOptedInToFreeTrial ) {
        NSLog(@"Found Free Trial Purchase: [%@] - Setting free trial end date accordingly", freeTrialPurchaseDate);
        NSDate* endDate = [AppPreferences.sharedInstance calculateFreeTrialEndDateFromDate:freeTrialPurchaseDate];
        AppPreferences.sharedInstance.freeTrialEnd = endDate;

        
        [[NSNotificationCenter defaultCenter] postNotificationName:kProStatusChangedNotificationKey object:nil];
    }
    
    if ( CustomizationManager.isAProBundle ) {
        NSLog(@"Upgrading App to Pro as Receipt is Good and this is a Pro edition...");
        [AppPreferences.sharedInstance setPro:YES];
        AppPreferences.sharedInstance.appHasBeenDowngradedToFreeEdition = NO;
    }
    else if ( [self receiptHasProEntitlements] ) {
        NSLog(@"Upgrading App to Pro as Entitlement found in Receipt...");
        [AppPreferences.sharedInstance setPro:YES];
        
        AppPreferences.sharedInstance.appHasBeenDowngradedToFreeEdition = NO;
    }
    else {
        if ( AppPreferences.sharedInstance.isPro ) {

            
            NSLog(@"PRO Entitlement NOT found in Receipt, incrementing fail count to allow for grace period but very likely app not entitled to Pro...");
                      
            AppPreferences.sharedInstance.numberOfEntitlementCheckFails++;

            



        }
        else {
            NSLog(@"App Pro Entitlement not found in Receipt... leaving downgraded...");
        }
    }
}

- (BOOL)receiptHasProEntitlements {
    BOOL lifetime = [[RMAppReceipt bundleReceipt] containsInAppPurchaseOfProductIdentifier:kIapProId]; 
    
    NSDate* now = [NSDate date];
    BOOL monthly = [[RMAppReceipt bundleReceipt] containsActiveAutoRenewableSubscriptionOfProductIdentifier:kMonthly forDate:now];
    BOOL threeMonthly = [[RMAppReceipt bundleReceipt] containsActiveAutoRenewableSubscriptionOfProductIdentifier:k3Monthly forDate:now];
    BOOL yearly = [[RMAppReceipt bundleReceipt] containsActiveAutoRenewableSubscriptionOfProductIdentifier:kYearly forDate:now];
    
    NSLog(@"Found Lifetime=%d, Monthly=%d, 3 Monthly=%d, Yearly=%d", lifetime, monthly, threeMonthly, yearly);
    
    return lifetime || monthly || threeMonthly || yearly;
}

- (void)loadAppStoreProducts {
    self.readyState = kWaitingOnAppStoreProducts;
    self.products = @{};

    NSSet *products = [NSSet setWithArray:@[kIapProId, kMonthly, kYearly, kIapFreeTrial]];
    
    [[RMStore defaultStore] requestProducts:products success:^(NSArray *products, NSArray *invalidProductIdentifiers) {
        self.products = [NSMutableDictionary dictionary];
        if (products) {
            for (SKProduct *validProduct in products) {
                NSLog(@"Got App Store Product [%@-%@]",
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
        NSLog(@"Error Retrieving IAP Products: [%@]", error);
        self.readyState = kCouldNotGetProducts;
        if(self.productsAvailableNotify) {
            self.productsAvailableNotify();
        }
    }];
}

- (void)checkForSaleAndNotify {
    if (@available(iOS 11.2, *)) {
        if(self.yearlyProduct.introductoryPrice) {
            [NSNotificationCenter.defaultCenter postNotificationName:kAppStoreSaleNotificationKey object:nil];
        }
    }
}

- (NSDictionary<NSString *,SKProduct *> *)availableProducts {
    return self.readyState == kReady ? [self.products copy] : @{};
}

- (void)restorePrevious:(RestoreCompletionBlock)completion {
    [RMStore.defaultStore restoreTransactionsOnSuccess:^(NSArray *transactions) {
        NSLog(@"Restore Done Successfully: [%@]", transactions);

        for (SKPaymentTransaction* pt in transactions) {
            NSLog(@"%@-%@", pt.originalTransaction.payment.productIdentifier, pt.originalTransaction.transactionDate);
        }
        
        [self checkReceiptForTrialAndProEntitlements];
        
        completion(nil);
    } failure:^(NSError *error) {
        completion(error);
    }];
}

- (void)purchaseAndCheckReceipts:(SKProduct *)product completion:(PurchaseCompletionBlock)completion {
    if(![SKPaymentQueue canMakePayments]) {
        completion([Utils createNSError:NSLocalizedString(@"upgrade_mgr_purchases_are_disabled", @"Purchases are disabled on your device.") errorCode:-1]);
        return;
    }
    
    [[RMStore defaultStore] addPayment:product.productIdentifier
                               success:^(SKPaymentTransaction *transaction) {
        NSLog(@"Product purchased: [%@]", transaction);
        
        [self checkReceiptForTrialAndProEntitlements];

        completion(nil);
    } failure:^(SKPaymentTransaction *transaction, NSError *error) {
        NSLog(@"Something went wrong: [%@] error = [%@]", transaction, error);
        completion(error);
    }];
}



- (BOOL)hasPurchasedFreeTrial {
    return self.freeTrialPurchaseDate != nil;
}

- (BOOL)hasPurchasedLifeTime {
    if (RMAppReceipt.bundleReceipt == nil) {
        NSLog(@"bundleReceipt = nil");
        return NO;
    }

    RMAppReceiptIAP *iap = [RMAppReceipt.bundleReceipt.inAppPurchases firstOrDefault:^BOOL(RMAppReceiptIAP *iap) {
        return [iap.productIdentifier isEqualToString:kIapProId];
    }];
    
    return iap != nil;
}

- (BOOL)hasActiveYearlySubscription {
    NSDate* now = [NSDate date];
    return [[RMAppReceipt bundleReceipt] containsActiveAutoRenewableSubscriptionOfProductIdentifier:kYearly forDate:now];
}

- (BOOL)hasActiveMonthlySubscription {
    NSDate* now = [NSDate date];
    return [[RMAppReceipt bundleReceipt] containsActiveAutoRenewableSubscriptionOfProductIdentifier:kMonthly forDate:now];
}


- (NSDate*)freeTrialPurchaseDate {
    if (RMAppReceipt.bundleReceipt == nil) {
        NSLog(@"bundleReceipt = nil");
        return nil;
    }

    RMAppReceiptIAP *freeTrialIap = [RMAppReceipt.bundleReceipt.inAppPurchases firstOrDefault:^BOOL(RMAppReceiptIAP *iap) {
        return [iap.productIdentifier isEqualToString:kIapFreeTrial];
    }];
    
    if (freeTrialIap) {
        NSDate* date;
        if ( freeTrialIap.originalPurchaseDate ) {
            date = freeTrialIap.originalPurchaseDate;
        }
        else {
            NSLog(@"Could not get original purchase date using purchaseDate instead");
            date = freeTrialIap.purchaseDate;
        }
        
        if (date) {
            return date;
        }
        else {
            NSLog(@"Could not determine Free Trial Purchase date...");
            return nil;
        }
    }
    else {
        NSLog(@"No Free Trial Purchase Found...");
        return nil;
    }
}

- (void)startFreeTrial:(PurchaseCompletionBlock)completion {
    if ( self.freeTrialProduct ) {
        [self purchaseAndCheckReceipts:self.freeTrialProduct completion:completion];
    }
    else {
        NSLog(@"Free Trial product unavailable");
        completion([Utils createNSError:@"Free Trial product unavailable" errorCode:-2345]);
    }
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

- (SKProduct *)freeTrialProduct {
    return self.availableProducts[kIapFreeTrial];
}

@end
