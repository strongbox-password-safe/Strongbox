//
//  DatabaseAuditorConfiguration.m
//  Strongbox
//
//  Created by Mark on 17/04/2020.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import "DatabaseAuditorConfiguration.h"

const int kDefaultMinimumLength = 12;
const NSUInteger kDefaultLowEntropyThreshold = 36; // bits

@implementation DatabaseAuditorConfiguration

+ (instancetype)defaults {
    return [[DatabaseAuditorConfiguration alloc] init];
}

- (instancetype)init {
    self = [super init];
    if (self) {
        self.checkForTwoFactorAvailable = NO;
        
        self.auditInBackground = YES;
        self.checkForNoPasswords = NO;
        self.checkForDuplicatedPasswords = YES;
        self.caseInsensitiveMatchForDuplicates = YES;
        self.checkForCommonPasswords = YES;
        self.checkForLowEntropy = YES;
        self.lowEntropyThreshold = kDefaultLowEntropyThreshold;
        
        self.levenshteinSimilarityThreshold = 0.75f;
        self.minimumLength = kDefaultMinimumLength;
        self.checkForMinimumLength = NO;

        self.checkForSimilarPasswords = NO; 
        self.checkHibp = NO; 
        
        self.lastKnownAuditIssueCount = nil;
        self.showAuditPopupNotifications = NO;
        self.hibpCaveatAccepted = NO;
        self.hibpCheckForNewBreachesIntervalSeconds = 7 * 24 * 60 * 60; 
        self.lastHibpOnlineCheck = nil;
        
        self.excludeShortNumericPINCodes = YES;
    }
        
    return self;
}

- (BOOL)showCachedHibpHits {
    return YES;
}




+ (instancetype)fromJsonSerializationDictionary:(NSDictionary *)jsonDictionary {
    DatabaseAuditorConfiguration* ret = DatabaseAuditorConfiguration.defaults;
    
    if (jsonDictionary[@"auditInBackground"] != nil ) ret.auditInBackground = ((NSNumber*)(jsonDictionary[@"auditInBackground"])).boolValue;
    if (jsonDictionary[@"checkForNoPasswords"] != nil ) ret.checkForNoPasswords = ((NSNumber*)(jsonDictionary[@"checkForNoPasswords"])).boolValue;
    if (jsonDictionary[@"checkForDuplicatedPasswords"] != nil ) ret.checkForDuplicatedPasswords = ((NSNumber*)(jsonDictionary[@"checkForDuplicatedPasswords"])).boolValue;
    if (jsonDictionary[@"caseInsensitiveMatchForDuplicates"] != nil ) ret.caseInsensitiveMatchForDuplicates = ((NSNumber*)(jsonDictionary[@"caseInsensitiveMatchForDuplicates"])).boolValue;
    if (jsonDictionary[@"checkForCommonPasswords"] != nil ) ret.checkForCommonPasswords = ((NSNumber*)(jsonDictionary[@"checkForCommonPasswords"])).boolValue;
    if (jsonDictionary[@"checkForLowEntropy"] != nil ) ret.checkForLowEntropy = ((NSNumber*)(jsonDictionary[@"checkForLowEntropy"])).boolValue;
    if (jsonDictionary[@"checkForSimilarPasswords"] != nil ) ret.checkForSimilarPasswords = ((NSNumber*)(jsonDictionary[@"checkForSimilarPasswords"])).boolValue;
    if (jsonDictionary[@"levenshteinSimilarityThreshold"] != nil ) ret.levenshteinSimilarityThreshold = ((NSNumber*)(jsonDictionary[@"levenshteinSimilarityThreshold"])).doubleValue;
    if (jsonDictionary[@"minimumLength"] != nil ) ret.minimumLength = ((NSNumber*)(jsonDictionary[@"minimumLength"])).unsignedIntegerValue;
    if (jsonDictionary[@"checkForMinimumLength"] != nil ) ret.checkForMinimumLength = ((NSNumber*)(jsonDictionary[@"checkForMinimumLength"])).boolValue;
    if (jsonDictionary[@"checkHibp"] != nil ) ret.checkHibp = ((NSNumber*)(jsonDictionary[@"checkHibp"])).boolValue;
    if (jsonDictionary[@"showAuditPopupNotifications2"] != nil ) ret.showAuditPopupNotifications = ((NSNumber*)(jsonDictionary[@"showAuditPopupNotifications2"])).boolValue;
    if (jsonDictionary[@"hibpCaveatAccepted"] != nil ) ret.hibpCaveatAccepted = ((NSNumber*)(jsonDictionary[@"hibpCaveatAccepted"])).boolValue;
    if (jsonDictionary[@"hibpCheckForNewBreachesIntervalSeconds"] != nil ) ret.hibpCheckForNewBreachesIntervalSeconds = ((NSNumber*)(jsonDictionary[@"hibpCheckForNewBreachesIntervalSeconds"])).unsignedIntegerValue;

    if (jsonDictionary[@"lastHibpOnlineCheck"] != nil ) ret.lastHibpOnlineCheck = [NSDate dateWithTimeIntervalSinceReferenceDate:((NSNumber*)(jsonDictionary[@"lastHibpOnlineCheck"])).doubleValue];
    if (jsonDictionary[@"lastKnownAuditIssueCount"] != nil ) ret.lastKnownAuditIssueCount = ((NSNumber*)(jsonDictionary[@"lastKnownAuditIssueCount"]));
    if (jsonDictionary[@"lowEntropyThreshold"] != nil ) ret.lowEntropyThreshold = ((NSNumber*)(jsonDictionary[@"lowEntropyThreshold"])).unsignedIntegerValue;
    if (jsonDictionary[@"checkForTwoFactorAvailable"] != nil ) ret.checkForTwoFactorAvailable = ((NSNumber*)(jsonDictionary[@"checkForTwoFactorAvailable"])).boolValue;
    if (jsonDictionary[@"excludeShortNumericPINCodes"] != nil ) ret.excludeShortNumericPINCodes = ((NSNumber*)(jsonDictionary[@"excludeShortNumericPINCodes"])).boolValue;
    if (jsonDictionary[@"lastDuration"] != nil ) ret.lastDuration = ((NSNumber*)(jsonDictionary[@"lastDuration"])).doubleValue;

    return ret;
}

- (NSDictionary *)getJsonSerializationDictionary {
    NSMutableDictionary *ret = [NSMutableDictionary dictionaryWithDictionary:@{
        @"auditInBackground" : @(self.auditInBackground),
        @"checkForNoPasswords" : @(self.checkForNoPasswords),
        @"checkForDuplicatedPasswords" : @(self.checkForDuplicatedPasswords),
        @"caseInsensitiveMatchForDuplicates" : @(self.caseInsensitiveMatchForDuplicates),
        @"checkForCommonPasswords" : @(self.checkForCommonPasswords),
        @"checkForLowEntropy" : @(self.checkForLowEntropy),
        @"checkForSimilarPasswords" : @(self.checkForSimilarPasswords),
        @"levenshteinSimilarityThreshold" : @(self.levenshteinSimilarityThreshold),
        @"minimumLength" : @(self.minimumLength),
        @"checkForMinimumLength" : @(self.checkForMinimumLength),
        @"checkHibp" : @(self.checkHibp),
        @"showAuditPopupNotifications2" : @(self.showAuditPopupNotifications),
        @"hibpCaveatAccepted" : @(self.hibpCaveatAccepted),
        @"hibpCheckForNewBreachesIntervalSeconds" : @(self.hibpCheckForNewBreachesIntervalSeconds),

        @"lowEntropyThreshold" : @(self.lowEntropyThreshold),
        @"checkForTwoFactorAvailable" : @(self.checkForTwoFactorAvailable),
        @"excludeShortNumericPINCodes" : @(self.excludeShortNumericPINCodes),
        @"lastDuration" : @(self.lastDuration),
    }];

    if( self.lastHibpOnlineCheck != nil) {
        ret[@"lastHibpOnlineCheck"] = @(self.lastHibpOnlineCheck.timeIntervalSinceReferenceDate);
    }
    
    if( self.lastKnownAuditIssueCount != nil) {
        ret[@"lastKnownAuditIssueCount"] = self.lastKnownAuditIssueCount;
    }

    return ret;
}



- (instancetype)initWithCoder:(NSCoder *)coder {
    if (self) {
        self.auditInBackground = [coder decodeBoolForKey:@"auditInBackground"];
        self.checkForNoPasswords = [coder decodeBoolForKey:@"checkForNoPasswords"];
        self.checkForDuplicatedPasswords = [coder decodeBoolForKey:@"checkForDuplicatedPasswords"];
        self.caseInsensitiveMatchForDuplicates = [coder decodeBoolForKey:@"caseInsensitiveMatchForDuplicates"];
        self.checkForCommonPasswords = [coder decodeBoolForKey:@"checkForCommonPasswords"];
        self.checkForLowEntropy = [coder decodeBoolForKey:@"checkForLowEntropy"];
        self.checkForSimilarPasswords = [coder decodeBoolForKey:@"checkForSimilarPasswords"];
        self.levenshteinSimilarityThreshold = [coder decodeFloatForKey:@"levenshteinSimilarityThreshold"];
        self.minimumLength = [coder decodeIntegerForKey:@"minimumLength"];
        self.checkForMinimumLength = [coder decodeBoolForKey:@"checkForMinimumLength"];
        self.checkHibp = [coder decodeBoolForKey:@"checkHibp"];
        self.hibpCaveatAccepted = [coder decodeBoolForKey:@"hibpCaveatAccepted"];
        self.hibpCheckForNewBreachesIntervalSeconds = [coder decodeIntegerForKey:@"hibpCheckForNewBreachesIntervalSeconds"];
        self.lowEntropyThreshold = [coder decodeIntegerForKey:@"lowEntropyThreshold"];
        self.checkForTwoFactorAvailable = [coder decodeBoolForKey:@"checkForTwoFactorAvailable"];
        self.lastHibpOnlineCheck = [coder decodeObjectForKey:@"lastHibpOnlineCheck"];
        self.lastKnownAuditIssueCount = [coder decodeObjectForKey:@"lastKnownAuditIssueCount"];

        if ( [coder containsValueForKey:@"showAuditPopupNotifications2"] ) {
            self.showAuditPopupNotifications = [coder decodeBoolForKey:@"showAuditPopupNotifications2"];
        }
        else {
            self.showAuditPopupNotifications = NO;
        }

        if ( [coder containsValueForKey:@"excludeShortNumericPINCodes"] ) {
            self.excludeShortNumericPINCodes = [coder decodeBoolForKey:@"excludeShortNumericPINCodes"];
        }
        else {
            self.excludeShortNumericPINCodes = YES;
        }

        if ( [coder containsValueForKey:@"lastDuration"] ) {
            self.lastDuration = ((NSNumber*)[coder decodeObjectForKey:@"lastDuration"]).doubleValue;
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
    [coder encodeBool:self.checkForLowEntropy forKey:@"checkForLowEntropy"];
    [coder encodeBool:self.checkForSimilarPasswords forKey:@"checkForSimilarPasswords"];
    [coder encodeFloat:self.levenshteinSimilarityThreshold forKey:@"levenshteinSimilarityThreshold"];
    [coder encodeInteger:self.minimumLength forKey:@"minimumLength"];
    [coder encodeBool:self.checkForMinimumLength forKey:@"checkForMinimumLength"];
    [coder encodeBool:self.checkHibp forKey:@"checkHibp"];
    [coder encodeBool:self.showAuditPopupNotifications forKey:@"showAuditPopupNotifications2"];
    [coder encodeBool:self.hibpCaveatAccepted forKey:@"hibpCaveatAccepted"];
    [coder encodeInteger:self.hibpCheckForNewBreachesIntervalSeconds forKey:@"hibpCheckForNewBreachesIntervalSeconds"];
    [coder encodeInteger:self.lowEntropyThreshold forKey:@"lowEntropyThreshold"];
    [coder encodeBool:self.checkForTwoFactorAvailable forKey:@"checkForTwoFactorAvailable"];
    [coder encodeObject:self.lastHibpOnlineCheck forKey:@"lastHibpOnlineCheck"];
    [coder encodeObject:self.lastKnownAuditIssueCount forKey:@"lastKnownAuditIssueCount"];
    [coder encodeBool:self.excludeShortNumericPINCodes forKey:@"excludeShortNumericPINCodes"];
    
    [coder encodeObject:@(self.lastDuration) forKey:@"lastDuration"];
}

- (NSString *)debugDescription {
    return [NSString stringWithFormat:@"<%@: %p> %@", [self class], self, [self getJsonSerializationDictionary]];
}

- (NSString *)description {
    return [NSString stringWithFormat:@"%@",  [self getJsonSerializationDictionary]];
}

@end
