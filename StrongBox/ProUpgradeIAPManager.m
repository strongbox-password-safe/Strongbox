//
//  SubscriptionManager.m
//  Strongbox-iOS
//
//  Created by Mark on 04/02/2019.
//  Copyright © 2019 Mark McGuill. All rights reserved.
//

#import "ProUpgradeIAPManager.h"
#import "NSArray+Extensions.h"
#import "Utils.h"
#import "RMStore.h"
#import "RMStoreAppReceiptVerifier.h"
#import "RMAppReceipt.h"
#import "Alerts.h"
#import "SharedAppAndAutoFillSettings.h"
#import "Settings.h"
#import "Model.h"

static NSString * const kProFamilyEditionBundleId = @"com.markmcguill.strongbox.pro";

static NSString* const kIapProId =  @"com.markmcguill.strongbox.pro";
static NSString* const kMonthly =  @"com.strongbox.markmcguill.upgrade.pro.monthly";
static NSString* const k3Monthly =  @"com.strongbox.markmcguill.upgrade.pro.3monthly";
static NSString* const kYearly =  @"com.strongbox.markmcguill.upgrade.pro.yearly";
static NSString* const kIapFreeTrial =  @"com.markmcguill.strongbox.ios.iap.freetrial";
//kTestConsumable @"com.markmcguill.strongbox.testconsumable"

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
        
        // See if we can auto upgrade the app if Pro is available
        
        RMStoreAppReceiptVerifier *verificator = [[RMStoreAppReceiptVerifier alloc] init];
        if ([verificator verifyAppReceipt]) {
            NSLog(@"App Receipt looks ok... checking for Valid Pro IAP purchases...");
            [self checkVerifiedReceiptIsEntitledToPro:nil];
        }
        else {
            NSLog(@"Startup receipt check failed...");
        }
    });
}

- (void)performScheduledProEntitlementsCheckIfAppropriate:(UIViewController*)vc {
    if(Settings.sharedInstance.lastEntitlementCheckAttempt != nil) {
        NSCalendar *gregorian = [[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian];
        
        NSDateComponents *components = [gregorian components:NSCalendarUnitDay
                                                    fromDate:Settings.sharedInstance.lastEntitlementCheckAttempt
                                                      toDate:[NSDate date]
                                                     options:0];
        
        NSInteger days = [components day];
        
        NSLog(@"%ld days since last entitlement check... [%@]", (long)days, Settings.sharedInstance.lastEntitlementCheckAttempt);
        
        if(days == 0) { // Already checked today...
            NSLog(@"Already checked entitlements today... not rechecking...");
            return;
        }
        
        // Last check was successful and was less than a week ago... no need to check again so soon
        
        if(Settings.sharedInstance.numberOfEntitlementCheckFails == 0 &&  days < 5) {
            NSLog(@"We had a successful check recently, not rechecking...");
            return;
        }
        else {
            NSLog(@"Rechecking since numberOfFails = %lu and days = %ld...", (unsigned long)Settings.sharedInstance.numberOfEntitlementCheckFails, (long)days);
        }
    }

    NSLog(@"Performing Scheduled Check of Entitlements...");
    
    if(Settings.sharedInstance.numberOfEntitlementCheckFails < 10) {
        [self checkReceiptForTrialAndProEntitlements:vc];
    }
    else {
        // For now - we will warn and ask to message support so we can handle this gracefully if someone is struggling...
        [Alerts info:vc
               title:NSLocalizedString(@"upgrade_mgr_entitlements_error_title", @"Strongbox Entitlements Error")
             message:NSLocalizedString(@"upgrade_mgr_entitlements_error_message", @"Strongbox is having trouble verifying its App Store entitlements. This means the App must be downgraded to the Free version. Please contact support@strongboxsafe.com if you think this is in error.")];
    
        [SharedAppAndAutoFillSettings.sharedInstance setPro:NO];
    }
}

- (void)checkReceiptForTrialAndProEntitlements:(UIViewController*)vc { // Don't want to do a refresh if we're launching...
    Settings.sharedInstance.lastEntitlementCheckAttempt = [NSDate date];
    
    RMStoreAppReceiptVerifier *verificator = [[RMStoreAppReceiptVerifier alloc] init];
    if ([verificator verifyAppReceipt]) {
        NSLog(@"App Receipt looks ok... checking for Valid Pro IAP purchases...");
        [self checkVerifiedReceiptIsEntitledToPro:vc];
    }
    else {
        NSLog(@"Receipt Not Good... Refreshing...");

        [[RMStore defaultStore] refreshReceiptOnSuccess:^{
            if ([verificator verifyAppReceipt]) {
                NSLog(@"App Receipt looks ok... checking for Valid Pro IAP purchases...");
                [self checkVerifiedReceiptIsEntitledToPro:vc];
            }
            else {
                NSLog(@"Receipt not good even after refresh");
                Settings.sharedInstance.numberOfEntitlementCheckFails++;
            }
        } failure:^(NSError *error) {
            NSLog(@"Refresh Receipt - Error [%@]", error);
            Settings.sharedInstance.numberOfEntitlementCheckFails++;
        }];
    }
}

- (void)checkVerifiedReceiptIsEntitledToPro:(UIViewController*)vc {
    Settings.sharedInstance.numberOfEntitlementCheckFails = 0;
    
    NSDate* freeTrialPurchaseDate = ProUpgradeIAPManager.sharedInstance.freeTrialPurchaseDate;
    if(freeTrialPurchaseDate && !SharedAppAndAutoFillSettings.sharedInstance.hasOptedInToFreeTrial) {
        NSLog(@"Found Free Trial Purchase: [%@] - Setting free trial end date accordingly", freeTrialPurchaseDate);
        NSDate* endDate = [SharedAppAndAutoFillSettings.sharedInstance calculateFreeTrialEndDateFromDate:freeTrialPurchaseDate];
        SharedAppAndAutoFillSettings.sharedInstance.freeTrialEnd = endDate;

        // This should update the main screen
        [[NSNotificationCenter defaultCenter] postNotificationName:kProStatusChangedNotificationKey object:nil];
    }
    
    if ([ProUpgradeIAPManager isProFamilyEdition]) {
        NSLog(@"Upgrading App to Pro as Receipt is Good and this is the Pro Family edition...");
        [SharedAppAndAutoFillSettings.sharedInstance setPro:YES];
    }
    else if([self receiptHasProEntitlements]) {
        NSLog(@"Upgrading App to Pro as Entitlement found in Receipt...");
        [SharedAppAndAutoFillSettings.sharedInstance setPro:YES];
    }
    else {
        if(SharedAppAndAutoFillSettings.sharedInstance.isPro) {
            NSLog(@"Downgrading App as Entitlement NOT found in Receipt...");
            
            if(vc) {
                [Alerts info:vc
                       title:NSLocalizedString(@"upgrade_mgr_downgrade_title", @"Strongbox Downgrade")
                     message:NSLocalizedString(@"upgrade_mgr_downgrade_message", @"It looks like this app is no longer entitled to all the Pro features. These will be limited now. If you believe this is incorrect, please get in touch with support@strongboxsafe.com to get some help with this. Please include your purchase receipt.")];
            }
            [SharedAppAndAutoFillSettings.sharedInstance setPro:NO];
        }
        else {
            NSLog(@"App Pro Entitlement not found in Receipt... leaving downgraded...");
        }
    }
}

- (BOOL)receiptHasProEntitlements {
    BOOL lifetime = [[RMAppReceipt bundleReceipt] containsInAppPurchaseOfProductIdentifier:kIapProId]; // What about cancellation?
    
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
        
        [self checkReceiptForTrialAndProEntitlements:nil];
        
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
        
        [self checkReceiptForTrialAndProEntitlements:nil];

        completion(nil);
    } failure:^(SKPaymentTransaction *transaction, NSError *error) {
        NSLog(@"Something went wrong: [%@] error = [%@]", transaction, error);
        completion(error);
    }];
}

+ (BOOL)isProFamilyEdition {
    NSString* bundleId = [Utils getAppBundleId];
    return [bundleId isEqualToString:kProFamilyEditionBundleId];
}

//

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

- (NSDate*)freeTrialPurchaseDate {
    if (RMAppReceipt.bundleReceipt == nil) {
        NSLog(@"bundleReceipt = nil");
        return nil;
    }

    RMAppReceiptIAP *freeTrialIap = [RMAppReceipt.bundleReceipt.inAppPurchases firstOrDefault:^BOOL(RMAppReceiptIAP *iap) {
        return [iap.productIdentifier isEqualToString:kIapFreeTrial];
    }];
    
    if (freeTrialIap) {
        NSDate* date = freeTrialIap.originalPurchaseDate;
        NSLog(@"Date vs Orig: [%@] vs [%@]", date, freeTrialIap.originalPurchaseDate);
        
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
    if (self.freeTrialProduct) {
        [self purchaseAndCheckReceipts:self.freeTrialProduct completion:completion];
    }
    else {
        NSLog(@"Free Trial product unavailable");
        completion([Utils createNSError:@"Free Trial product unavailable" errorCode:-2345]);
    }
}

//

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
