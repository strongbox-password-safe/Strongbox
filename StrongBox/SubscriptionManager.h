//
//  SubscriptionManager.h
//  Strongbox-iOS
//
//  Created by Mark on 04/02/2019.
//  Copyright © 2019 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SubscriptionOption.h"

NS_ASSUME_NONNULL_BEGIN

@interface SubscriptionManager : NSObject

- (void)getAvailableSubscriptions:(void (^)(NSError* error, NSArray<SubscriptionOption*>* options))completion;
- (void)purchase:(SubscriptionOption*)option;

@end

NS_ASSUME_NONNULL_END
