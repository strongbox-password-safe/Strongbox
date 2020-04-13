//
//  SubscriptionManager.h
//  Strongbox-iOS
//
//  Created by Mark on 04/02/2019.
//  Copyright © 2019 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <StoreKit/StoreKit.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM (unsigned int, UpgradeManagerState) {
    kInitial,
    kWaitingOnAppStoreProducts,
    kReady,
    kCouldNotGetProducts,
};

typedef void (^RestoreCompletionBlock)(NSError * _Nullable error);
typedef void (^PurchaseCompletionBlock)(NSError * _Nullable error);
typedef void (^ProductsAvailableNotificationBlock)(void);

@interface ProUpgradeIAPManager : NSObject

+ (instancetype)sharedInstance;

@property (readonly) UpgradeManagerState state;
@property (readonly) NSDictionary<NSString*, SKProduct*> *availableProducts;
@property ProductsAvailableNotificationBlock productsAvailableNotify;

- (void)initialize;
- (void)restorePrevious:(RestoreCompletionBlock)completion;

@property (readonly, nullable) SKProduct* monthlyProduct;
@property (readonly, nullable) SKProduct* yearlyProduct;
@property (readonly, nullable) SKProduct* lifeTimeProduct;

- (void)purchaseAndCheckReceipts:(SKProduct*)product completion:(PurchaseCompletionBlock)completion;

- (void)performScheduledProEntitlementsCheckIfAppropriate:(UIViewController*)vc;

+ (BOOL)isProFamilyEdition;

- (void)startFreeTrial:(PurchaseCompletionBlock)completion;

@property (readonly) BOOL hasPurchasedLifeTime;
@property (readonly) BOOL hasPurchasedFreeTrial;
@property (readonly) NSDate* freeTrialPurchaseDate;

@end

NS_ASSUME_NONNULL_END
