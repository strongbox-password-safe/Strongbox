//
//  DatabaseModelConfig.m
//  MacBox
//
//  Created by Strongbox on 15/06/2020.
//  Copyright © 2020 Mark McGuill. All rights reserved.
//

#import "DatabaseModelConfig.h"

@implementation DatabaseModelConfig

+ (instancetype)defaults {
    return [DatabaseModelConfig withPasswordConfig:PasswordGenerationConfig.defaults];
}

+ (instancetype)withPasswordConfig:(PasswordGenerationConfig *)passwordConfig {
    return [DatabaseModelConfig withPasswordConfig:passwordConfig sanityCheckInnerStream:YES];
}

+ (instancetype)withPasswordConfig:(PasswordGenerationConfig *)passwordConfig sanityCheckInnerStream:(BOOL)sanityCheckInnerStream {
    DatabaseModelConfig* config = [[DatabaseModelConfig alloc] initWithPasswordConfig:passwordConfig sanityCheckInnerStream:sanityCheckInnerStream];
        
    return config;
}

- (instancetype)initWithPasswordConfig:(PasswordGenerationConfig *)passwordConfig sanityCheckInnerStream:(BOOL)sanityCheckInnerStream {
    self = [super init];
    if (self) {
        _passwordGeneration = passwordConfig;
        _sanityCheckInnerStream = sanityCheckInnerStream;
    }
    return self;
}

@end
