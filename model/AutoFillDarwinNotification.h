//
//  AutoFillDarwinNotification.h
//  Strongbox
//
//  Created by Strongbox on 03/10/2023.
//  Copyright © 2023 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef void (^AutoFillDarwinCompletionBlock)(void);

@interface AutoFillDarwinNotification : NSObject

+ (void)sendNotification;
+ (void)registerForNotifications:(AutoFillDarwinCompletionBlock)completion;

@end

NS_ASSUME_NONNULL_END
