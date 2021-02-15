//
//  PasswordMaker.h
//  Strongbox
//
//  Created by Mark on 29/06/2019.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
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
- (NSString*)generateWithDefaultConfig;
- (NSString*)generateEmail;
- (NSString*)generateRandomWord;
    
- (BOOL)isCommonPassword:(NSString*)password;

#if TARGET_OS_IPHONE

- (void)promptWithUsernameSuggestions:(UIViewController*)viewController config:(PasswordGenerationConfig*)config action:(void (^)(NSString *response))action;
- (void)promptWithSuggestions:(UIViewController*)viewController config:(PasswordGenerationConfig*)config action:(void (^)(NSString *response))action;

#endif

- (NSString*)generateUsername;

@end

NS_ASSUME_NONNULL_END
