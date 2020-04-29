//
//  DatabaseAuditorConfiguration.m
//  Strongbox
//
//  Created by Mark on 17/04/2020.
//  Copyright © 2020 Mark McGuill. All rights reserved.
//

#import "DatabaseAuditorConfiguration.h"

const int kDefaultMinimumLength = 12;

@implementation DatabaseAuditorConfiguration

+ (instancetype)defaults {
    DatabaseAuditorConfiguration* config = [[DatabaseAuditorConfiguration alloc] init];

    config.auditInBackground = YES;
    config.checkForNoPasswords = NO;
    config.checkForDuplicatedPasswords = YES;
    config.caseInsensitiveMatchForDuplicates = YES;
    config.checkForCommonPasswords = YES;
    config.checkForSimilarPasswords = YES;
    config.levenshteinSimilarityThreshold = 0.75f;
    config.minimumLength = kDefaultMinimumLength;
    config.checkForMinimumLength = NO;
    
    return config;
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    if((self = [self init])) {
        self.auditInBackground = [coder decodeBoolForKey:@"auditInBackground"];
        self.checkForNoPasswords = [coder decodeBoolForKey:@"checkForNoPasswords"];
        self.checkForDuplicatedPasswords = [coder decodeBoolForKey:@"checkForDuplicatedPasswords"];
        self.caseInsensitiveMatchForDuplicates = [coder decodeBoolForKey:@"caseInsensitiveMatchForDuplicates"];
        self.checkForCommonPasswords = [coder decodeBoolForKey:@"checkForCommonPasswords"];
        self.checkForSimilarPasswords = [coder decodeBoolForKey:@"checkForSimilarPasswords"];
        self.levenshteinSimilarityThreshold = [coder decodeFloatForKey:@"levenshteinSimilarityThreshold"];
        
        if ([coder containsValueForKey:@"minimumLength"]) {
            self.minimumLength = [coder decodeIntegerForKey:@"minimumLength"];
        }
        else {
            self.minimumLength = kDefaultMinimumLength;
        }

        if ([coder containsValueForKey:@"checkForMinimumLength"]) {
            self.checkForMinimumLength = [coder decodeBoolForKey:@"checkForMinimumLength"];
        }
    }
    
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder {
    [coder encodeBool:self.auditInBackground forKey:@"auditInBackground"];
    [coder encodeBool:self.checkForNoPasswords forKey:@"checkForNoPasswords"];
    [coder encodeBool:self.checkForDuplicatedPasswords forKey:@"checkForDuplicatedPasswords"];
    [coder encodeBool:self.caseInsensitiveMatchForDuplicates forKey:@"caseInsensitiveMatchForDuplicates"];
    [coder encodeBool:self.checkForCommonPasswords forKey:@"checkForCommonPasswords"];
    [coder encodeBool:self.checkForSimilarPasswords forKey:@"checkForSimilarPasswords"];
    [coder encodeFloat:self.levenshteinSimilarityThreshold forKey:@"levenshteinSimilarityThreshold"];
    [coder encodeInteger:self.minimumLength forKey:@"minimumLength"];
    [coder encodeBool:self.checkForMinimumLength forKey:@"checkForMinimumLength"];
}

@end
