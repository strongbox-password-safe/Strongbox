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
        [self upgradeOrDowngradeBasedOnReceipt:NO]; // TODO: Do this in an hour or so again - this happens at startup and works but UI does not update
    });
}

- (void)upgradeOrDowngradeBasedOnReceipt:(BOOL)canRequestRefresh {
    RMStoreAppReceiptVerifier *verificator = [[RMStoreAppReceiptVerifier alloc] init];
    if ([verificator verifyAppReceipt]) {
        NSLog(@"App Receipt looks ok... checking for Valid Pro IAP purchases...");
        [self upgradeOrDowngradeBasedOnReceiptEntitlements];
    }
    else if(canRequestRefresh) {
        NSLog(@"Receipt Not Good... Refreshing...");

        [[RMStore defaultStore] refreshReceiptOnSuccess:^{
            if ([verificator verifyAppReceipt]) {
                NSLog(@"App Receipt looks ok... checking for Valid Pro IAP purchases...");
                [self upgradeOrDowngradeBasedOnReceiptEntitlements];
            }
            else {
                NSLog(@"Receipt not good even after refresh");
                // TODO: Have a counter or date on this, and try again... After too many fails... downgrade
            }
        } failure:^(NSError *error) {
            NSLog(@"Refresh Receipt - Error [%@]", error);
            // TODO: Have a counter or date on this, and try again... After too many fails... downgrade
        }];
    }
    else {
        NSLog(@"Receipt not good but cannot refresh right now...");
        // TODO: Have a counter or date on this, and try again... After too many fails... downgrade
    }
}

- (void)upgradeOrDowngradeBasedOnReceiptEntitlements {
    if([self receiptHasProEntitlements]) {
        NSLog(@"Upgrading App to Pro as Entitlement found in Receipt...");
        [Settings.sharedInstance setPro:YES];
    }
    else {
        if(Settings.sharedInstance.isPro) {
            NSLog(@"Downgrading App as Entitlement found in Receipt...");
            //[Settings.sharedInstance setPro:YES];
            // TODO: Enable in next release if all goes well
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

    NSSet *products = [NSSet setWithArray:@[kIapProId, kMonthly, k3Monthly, kYearly]];
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

-(NSDictionary<NSString *,SKProduct *> *)availableProducts {
    return self.readyState == kReady ? [self.products copy] : @{};
}

- (void)restorePrevious:(RestoreCompletionBlock)completion {
    [RMStore.defaultStore restoreTransactionsOnSuccess:^(NSArray *transactions) {
        NSLog(@"Restore Done Successfully: [%@]", transactions);

        [self upgradeOrDowngradeBasedOnReceipt:YES];
        
        completion(nil);
    } failure:^(NSError *error) {
        completion(error);
    }];
}

- (void)purchase:(NSString *)productId completion:(PurchaseCompletionBlock)completion {
    if(![SKPaymentQueue canMakePayments]) {
        completion([Utils createNSError:@"Purchases are disabled on your device." errorCode:-1]);
        return;
    }
    
    [[RMStore defaultStore] addPayment:productId success:^(SKPaymentTransaction *transaction) {
        NSLog(@"Product purchased: [%@]", transaction);
        
        [self upgradeOrDowngradeBasedOnReceipt:YES];

        completion(nil);
    } failure:^(SKPaymentTransaction *transaction, NSError *error) {
        NSLog(@"Something went wrong: [%@] error = [%@]", transaction, error);
        completion(error);
    }];
}

@end
