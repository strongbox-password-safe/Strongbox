//
//  SubscriptionOption.h
//  Strongbox-iOS
//
//  Created by Mark on 04/02/2019.
//  Copyright © 2019 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <StoreKit/StoreKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface SubscriptionOption : NSObject

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithProduct:(SKProduct*)product;

@property SKProduct* storeKitProduct;

@end

NS_ASSUME_NONNULL_END
