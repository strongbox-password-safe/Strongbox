//
//  PasswordStrengthConfig.m
//  Strongbox
//
//  Created by Strongbox on 12/04/2021.
//  Copyright © 2021 Mark McGuill. All rights reserved.
//

#import "PasswordStrengthConfig.h"

@implementation PasswordStrengthConfig

+ (instancetype)defaults {
    PasswordStrengthConfig* config = [[PasswordStrengthConfig alloc] init];
    
    config.algorithm = kPasswordStrengthAlgorithmZxcvbn;
    config.adversaryGuessesPerSecond = 1000000000; 

    
    return config;
}

- (void)encodeWithCoder:(NSCoder *)encoder {
    [encoder encodeInteger:self.algorithm forKey:@"algorithm"];
    [encoder encodeInteger:self.adversaryGuessesPerSecond forKey:@"adversaryGuessesPerSecond"];
}

- (id)initWithCoder:(NSCoder *)decoder {
    if((self = [self init])) {
        self.algorithm = [decoder decodeIntegerForKey:@"algorithm"];
        
        if ( [decoder containsValueForKey:@"adversaryGuessesPerSecond"] ) {
            self.adversaryGuessesPerSecond = [decoder decodeIntegerForKey:@"adversaryGuessesPerSecond"];
        }
    }

    return self;
}

@end
