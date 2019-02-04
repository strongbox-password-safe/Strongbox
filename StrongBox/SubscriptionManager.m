//
//  SubscriptionManager.m
//  Strongbox-iOS
//
//  Created by Mark on 04/02/2019.
//  Copyright © 2019 Mark McGuill. All rights reserved.
//

#import "SubscriptionManager.h"
#import "NSArray+Extensions.h"
#import "Utils.h"

static NSString* const kMonthly =  @"com.strongbox.markmcguill.upgrade.pro.monthly";
static NSString* const k3Monthly =  @"com.strongbox.markmcguill.upgrade.pro.3monthly";
static NSString* const kYearly =  @"com.strongbox.markmcguill.upgrade.pro.yearly";

@interface SubscriptionManager () <SKProductsRequestDelegate, SKPaymentTransactionObserver>

@property SKProductsRequest *productsRequest;
@property (nonatomic, copy) void (^completion)(NSError* error, NSArray<SubscriptionOption*>* options);

@end

@implementation SubscriptionManager

+ (instancetype)defaultInstance {
    static SubscriptionManager *sharedInstance = nil;
    static dispatch_once_t onceToken;
    
    dispatch_once(&onceToken, ^{
        sharedInstance = [[SubscriptionManager alloc] init];
    });
    return sharedInstance;
}

- (instancetype)init {
    if(self = [super init]) {
        [SKPaymentQueue.defaultQueue addTransactionObserver:self]; // TODO: How will this interact with existing purchase
    }
    
    return self;
}

-(void)getAvailableSubscriptions:(void (^)(NSError* error, NSArray<SubscriptionOption*>* options))completion {
    self.completion = completion;
    
    NSSet *productIdentifiers = [NSSet setWithArray:@[kMonthly, k3Monthly, kYearly]];
    self.productsRequest = [[SKProductsRequest alloc] initWithProductIdentifiers:productIdentifiers];
    self.productsRequest.delegate = self;
    [self.productsRequest start];
}

- (void)purchase:(SubscriptionOption *)option {
    SKPayment* payment = [SKPayment paymentWithProduct:option.storeKitProduct];
    [SKPaymentQueue.defaultQueue addPayment:payment];
}

- (void)productsRequest:(nonnull SKProductsRequest *)request didReceiveResponse:(nonnull SKProductsResponse *)response { 
    NSLog(@"didReceiveResponse: %@", response);

    if(response.products == nil) {
        self.completion([Utils createNSError:@"Nil products returned from StoreKit" errorCode:-1], nil);
    }
    
    NSArray<SubscriptionOption*>* options = [response.products map:^id _Nonnull(SKProduct * _Nonnull obj, NSUInteger idx) {
        return [[SubscriptionOption alloc] initWithProduct:obj];
    }];
    
    self.completion(nil, options);
}

- (void)requestDidFinish:(SKRequest *)request {
    NSLog(@"requestDidFinish");
}

- (void)request:(SKRequest *)request didFailWithError:(NSError *)error {
    NSLog(@"didFailWithError [%@]", error); // TODO: call completion
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Payment processing

- (void)paymentQueue:(nonnull SKPaymentQueue *)queue updatedTransactions:(nonnull NSArray<SKPaymentTransaction *> *)transactions {
    // TODO:
    NSLog(@"updatedTransactions");

    for (SKPaymentTransaction *transaction in transactions) {
        switch (transaction.transactionState) {
            case SKPaymentTransactionStatePurchasing:
                NSLog(@"SKPaymentTransactionStatePurchasing");
                break;
            case SKPaymentTransactionStatePurchased:
                NSLog(@"SKPaymentTransactionStatePurchased: %@ - [%@]", transaction.payment.productIdentifier, [NSBundle.mainBundle appStoreReceiptURL]);
                break;
            case SKPaymentTransactionStateFailed:
                NSLog(@"SKPaymentTransactionStateFailed");
                break;
            case SKPaymentTransactionStateRestored:
                NSLog(@"SKPaymentTransactionStateRestored");
                break;
            case SKPaymentTransactionStateDeferred:
                NSLog(@"SKPaymentTransactionStateDeferred");
                break;
        }
    }
    // NSBundle.mainBundle.appStoreReceiptURL
}

- (void)paymentQueue:(SKPaymentQueue *)queue removedTransactions:(NSArray<SKPaymentTransaction *> *)transactions {
    NSLog(@"removedTransactions");
}

// Sent when an error is encountered while adding transactions from the user's purchase history back to the queue.
- (void)paymentQueue:(SKPaymentQueue *)queue restoreCompletedTransactionsFailedWithError:(NSError *)error {
    NSLog(@"restoreCompletedTransactionsFailedWithError");
}

// Sent when all transactions from the user's purchase history have successfully been added back to the queue.
- (void)paymentQueueRestoreCompletedTransactionsFinished:(SKPaymentQueue *)queue {
    NSLog(@"paymentQueueRestoreCompletedTransactionsFinished");
}

@end
