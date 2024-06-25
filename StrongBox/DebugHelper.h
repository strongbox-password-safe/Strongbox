//
//  DebugHelper.h
//  Strongbox-iOS
//
//  Created by Mark on 01/10/2019.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface DebugHelper : NSObject

+ (void)getAboutDebugString:(void(^)(NSString*))completion;
+ (void)getCrashEmailDebugString:(void(^)(NSString*))completion;

@end

NS_ASSUME_NONNULL_END
