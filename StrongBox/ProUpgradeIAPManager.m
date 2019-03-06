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
    // TODO: Check we have a valid purchase/receipt and upgrade/downgrade based on that... periodically

//    [[RMStore defaultStore] refreshReceiptOnSuccess:^{
//        NSLog(@"Receipt refreshed");
//    } failure:^(NSError *error) {
//        NSLog(@"Something went wrong");
//    }];
    self.receiptVerifier = [[RMStoreAppReceiptVerifier alloc] init];
    //RMStore.defaultStore.receiptVerifier = self.receiptVerifier;
        
    //return YES;
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0L), ^{
        [self loadAppStoreProducts];
    });
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
        
        // TODO: Check the transactions for valid purchase...
        if(transactions.count > 0) {
            [Settings.sharedInstance setPro:YES];
        }
        
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
        
        // TODO: Check the transactions for valid purchase...
        [Settings.sharedInstance setPro:YES];
        
        completion(nil);
    } failure:^(SKPaymentTransaction *transaction, NSError *error) {
        NSLog(@"Something went wrong: [%@] error = [%@]", transaction, error);
        completion(error);
    }];
}

@end
