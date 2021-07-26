//
//  PasswordStrengthTester.h
//  Strongbox
//
//  Created by Strongbox on 12/04/2021.
//  Copyright © 2021 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "PasswordStrength.h"
#import "PasswordStrengthConfig.h"

NS_ASSUME_NONNULL_BEGIN

@interface PasswordStrengthTester : NSObject

+ (PasswordStrength *)getStrength:(NSString *)password config:(PasswordStrengthConfig*)config;

+ (double)getSimpleStrength:(NSString*)password;
+ (double)getZxcvbnStrength:(NSString*)password;

@end

NS_ASSUME_NONNULL_END
