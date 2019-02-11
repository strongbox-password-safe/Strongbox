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

static NSString* const kIapProId =  @"com.markmcguill.strongbox.pro";
static NSString* const kMonthly =  @"com.strongbox.markmcguill.upgrade.pro.monthly";
static NSString* const k3Monthly =  @"com.strongbox.markmcguill.upgrade.pro.3monthly";
static NSString* const kYearly =  @"com.strongbox.markmcguill.upgrade.pro.yearly";
//kTestConsumable @"com.markmcguill.strongbox.testconsumable"

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
- (void)purchase:(NSString*)productId completion:(PurchaseCompletionBlock)completion;

@end

NS_ASSUME_NONNULL_END
