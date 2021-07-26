//
//  PasswordStrengthConfig.h
//  Strongbox
//
//  Created by Strongbox on 12/04/2021.
//  Copyright © 2021 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN


typedef NS_ENUM (NSUInteger, PasswordStrengthAlgorithm) {
    kPasswordStrengthAlgorithmBasic,
    kPasswordStrengthAlgorithmZxcvbn,
};


@interface PasswordStrengthConfig : NSObject

+ (instancetype)defaults;

@property PasswordStrengthAlgorithm algorithm;
@property NSUInteger adversaryGuessesPerSecond;


@end

NS_ASSUME_NONNULL_END
