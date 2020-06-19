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
    DatabaseModelConfig* config = [[DatabaseModelConfig alloc] initWithPasswordConfig:passwordConfig];
        
    return config;
}

- (instancetype)initWithPasswordConfig:(PasswordGenerationConfig *)passwordConfig {
    self = [super init];
    if (self) {
        _passwordGeneration = passwordConfig;
    }
    return self;
}

@end
