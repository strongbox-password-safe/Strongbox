//
//  DatabaseAuditorConfiguration.m
//  Strongbox
//
//  Created by Mark on 17/04/2020.
//  Copyright © 2020 Mark McGuill. All rights reserved.
//

#import "DatabaseAuditorConfiguration.h"

@implementation DatabaseAuditorConfiguration

+ (instancetype)defaults {
    DatabaseAuditorConfiguration* config = [[DatabaseAuditorConfiguration alloc] init];

    config.startAuditOnUnlock = YES;
    config.checkForNoPasswords = YES;
    config.checkForDuplicatedPasswords = YES;
    config.caseInsensitiveMatchForDuplicates = YES;
    config.checkForCommonPasswords = YES;
    config.checkForSimilarPasswords = YES;
    config.levenshteinSimilarityThreshold = 0.75f;
    
    return config;
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    if((self = [self init])) {
        self.startAuditOnUnlock = [coder decodeBoolForKey:@"startAuditOnUnlock"];
        self.checkForNoPasswords = [coder decodeBoolForKey:@"checkForNoPasswords"];
        self.checkForDuplicatedPasswords = [coder decodeBoolForKey:@"checkForDuplicatedPasswords"];
        self.caseInsensitiveMatchForDuplicates = [coder decodeBoolForKey:@"caseInsensitiveMatchForDuplicates"];
        self.checkForCommonPasswords = [coder decodeBoolForKey:@"checkForCommonPasswords"];
        self.checkForSimilarPasswords = [coder decodeBoolForKey:@"checkForSimilarPasswords"];
        self.levenshteinSimilarityThreshold = [coder decodeFloatForKey:@"levenshteinSimilarityThreshold"];
    }
    
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder {
    [coder encodeBool:self.startAuditOnUnlock forKey:@"startAuditOnUnlock"];
    [coder encodeBool:self.checkForNoPasswords forKey:@"checkForNoPasswords"];
    [coder encodeBool:self.checkForDuplicatedPasswords forKey:@"checkForDuplicatedPasswords"];
    [coder encodeBool:self.caseInsensitiveMatchForDuplicates forKey:@"caseInsensitiveMatchForDuplicates"];
    [coder encodeBool:self.checkForCommonPasswords forKey:@"checkForCommonPasswords"];
    [coder encodeBool:self.checkForSimilarPasswords forKey:@"checkForSimilarPasswords"];
    [coder encodeFloat:self.levenshteinSimilarityThreshold forKey:@"levenshteinSimilarityThreshold"];
}

@end
