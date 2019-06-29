//
//  PasswordGenerationConfig.m
//  Strongbox
//
//  Created by Mark on 29/06/2019.
//  Copyright © 2019 Mark McGuill. All rights reserved.
//

#import "PasswordGenerationConfig.h"

@implementation PasswordGenerationConfig

+ (instancetype)defaults {
    PasswordGenerationConfig *ret = [[PasswordGenerationConfig alloc] init];
    
    ret.algorithm = kPasswordGenerationAlgorithmBasic;
    
    ret.basicLength = 16;
    ret.useCharacterGroups = @[@(kPasswordGenerationCharacterPoolLower),
                               @(kPasswordGenerationCharacterPoolUpper),
                               @(kPasswordGenerationCharacterPoolNumeric),
                               @(kPasswordGenerationCharacterPoolSymbols)];
    
    ret.easyReadCharactersOnly = YES;
    ret.nonAmbiguousOnly = YES;
    ret.pickFromEveryGroup = YES;
    
    ret.wordCount = 5;
//    ret.wordLists;
    ret.wordSeparator = @"-";
//    ret.casing;
    ret.hackerify = NO;
//    ret.addSalt

    return ret;
}

@end
