//
//  PasswordMaker.h
//  Strongbox
//
//  Created by Mark on 29/06/2019.
//  Copyright © 2019 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "PasswordGenerationConfig.h"

NS_ASSUME_NONNULL_BEGIN

@interface PasswordMaker : NSObject

+ (instancetype)sharedInstance;

- (NSString*)generateForConfig:(PasswordGenerationConfig*)config;
- (NSString*)generateForConfigOrDefault:(PasswordGenerationConfig*)config;

- (void)promptWithSuggestions:(UIViewController*)viewController usernames:(BOOL)usernames action:(void (^)(NSString *response))action;

- (NSString*)generateUsername;

@end

NS_ASSUME_NONNULL_END
