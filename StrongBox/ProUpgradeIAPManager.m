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
#import "Settings.h"
#import "RMStore.h"
#import "RMStoreAppReceiptVerifier.h"
#import "RMAppReceipt.h"
#import "Alerts.h"

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
            [self checkProEntitlements:nil];
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
        
        if(Settings.sharedInstance.numberOfEntitlementCheckFails == 0 &&  days < 3) {
            NSLog(@"We had a successful check recently, not rechecking...");
            return;
        }
        else {
            NSLog(@"Rechecking since numberOfFails = %lu and days = %ld...", (unsigned long)Settings.sharedInstance.numberOfEntitlementCheckFails, (long)days);
        }
    }

    NSLog(@"Performing Scheduled Check of Entitlements...");
    
    if(Settings.sharedInstance.numberOfEntitlementCheckFails < 8) {
        [self checkReceiptAndProEntitlements:vc];
    }
    else {
        // TODO: We should probably downgrade now... Something very funny is up
        // For now - we will warn and ask to message support so we can handle this gracefully if someone is struggling...
        [Alerts info:vc
               title:NSLocalizedString(@"upgrade_mgr_entitlements_error_title", @"Strongbox Entitlements Error")
             message:NSLocalizedString(@"upgrade_mgr_entitlements_error_message", @"Strongbox is having trouble verifying its App Store entitlements. This could lead to a future App downgrade. Please contact support@strongboxsafe.com to get some help with this.")];
    
        [self checkReceiptAndProEntitlements:vc];
    }
}

- (void)checkReceiptAndProEntitlements:(UIViewController*)vc { // Don't want to do a refresh if we're launching...
    Settings.sharedInstance.lastEntitlementCheckAttempt = [NSDate date];
    
    RMStoreAppReceiptVerifier *verificator = [[RMStoreAppReceiptVerifier alloc] init];
    if ([verificator verifyAppReceipt]) {
        NSLog(@"App Receipt looks ok... checking for Valid Pro IAP purchases...");
        [self checkProEntitlements:vc];
    }
    else {
        NSLog(@"Receipt Not Good... Refreshing...");

        [[RMStore defaultStore] refreshReceiptOnSuccess:^{
            if ([verificator verifyAppReceipt]) {
                NSLog(@"App Receipt looks ok... checking for Valid Pro IAP purchases...");
                [self checkProEntitlements:vc];
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

- (void)checkProEntitlements:(UIViewController*)vc {
    Settings.sharedInstance.numberOfEntitlementCheckFails = 0;
    
    if([self receiptHasProEntitlements]) {
        NSLog(@"Upgrading App to Pro as Entitlement found in Receipt...");
        [Settings.sharedInstance setPro:YES];
    }
    else {
        if(Settings.sharedInstance.isPro) {
            NSLog(@"Downgrading App as Entitlement NOT found in Receipt...");
            
            if(vc) {
                [Alerts info:vc
                       title:NSLocalizedString(@"upgrade_mgr_downgrade_title", @"Strongbox Downgrade")
                     message:NSLocalizedString(@"upgrade_mgr_downgrade_message", @"It looks like this app is no longer entitled to all the Pro features. These will be limited now. If you believe this is incorrect, please get in touch with support@strongboxsafe.com to get some help with this. Please include your purchase receipt.")];
            }
            [Settings.sharedInstance setPro:NO];
        }
        else {
            NSLog(@"App Pro Entitlement not found in Receipt... leaving downgraded...");
        }
    }
}

- (BOOL)receiptHasProEntitlements {
    BOOL lifetime = [[RMAppReceipt bundleReceipt] containsInAppPurchaseOfProductIdentifier:kIapProId]; // TODO: What about cancellation?
    
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

    NSSet *products = [NSSet setWithArray:@[kIapProId, kMonthly, kYearly]]; // k3Monthly,
    [[RMStore defaultStore] requestProducts:products success:^(NSArray *products, NSArray *invalidProductIdentifiers) {
        self.products = [NSMutableDictionary dictionary];
        if (products) {
            for (SKProduct *validProduct in products) {
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

- (NSDictionary<NSString *,SKProduct *> *)availableProducts {
    return self.readyState == kReady ? [self.products copy] : @{};
}

- (void)restorePrevious:(RestoreCompletionBlock)completion {
    [RMStore.defaultStore restoreTransactionsOnSuccess:^(NSArray *transactions) {
        NSLog(@"Restore Done Successfully: [%@]", transactions);

        [self checkReceiptAndProEntitlements:nil];
        
        completion(nil);
    } failure:^(NSError *error) {
        completion(error);
    }];
}

- (void)purchase:(NSString *)productId completion:(PurchaseCompletionBlock)completion {
    if(![SKPaymentQueue canMakePayments]) {
        completion([Utils createNSError:NSLocalizedString(@"upgrade_mgr_purchases_are_disabled", @"Purchases are disabled on your device.") errorCode:-1]);
        return;
    }
    
    [[RMStore defaultStore] addPayment:productId success:^(SKPaymentTransaction *transaction) {
        NSLog(@"Product purchased: [%@]", transaction);
        
        [self checkReceiptAndProEntitlements:nil];

        completion(nil);
    } failure:^(SKPaymentTransaction *transaction, NSError *error) {
        NSLog(@"Something went wrong: [%@] error = [%@]", transaction, error);
        completion(error);
    }];
}

@end
