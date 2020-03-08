//
//  PasswordMaker.h
//  Strongbox
//
//  Created by Mark on 29/06/2019.
//  Copyright © 2019 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "PasswordGenerationConfig.h"

#if TARGET_OS_IPHONE
#import <UIKit/UIKit.h>
#endif

NS_ASSUME_NONNULL_BEGIN

@interface PasswordMaker : NSObject

+ (instancetype)sharedInstance;

- (NSString*)generateForConfig:(PasswordGenerationConfig*)config;
- (NSString*)generateForConfigOrDefault:(PasswordGenerationConfig*)config;

#if TARGET_OS_IPHONE

- (void)promptWithUsernameSuggestions:(UIViewController*)viewController action:(void (^)(NSString *response))action;
- (void)promptWithSuggestions:(UIViewController*)viewController action:(void (^)(NSString *response))action;

#endif

- (NSString*)generateUsername;

@end

NS_ASSUME_NONNULL_END
