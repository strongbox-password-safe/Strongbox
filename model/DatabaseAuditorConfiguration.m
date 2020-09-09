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
    return [[DatabaseAuditorConfiguration alloc] init];
}

- (instancetype)init {
    self = [super init];
    if (self) {
        self.auditInBackground = YES;
        self.checkForNoPasswords = NO;
        self.checkForDuplicatedPasswords = YES;
        self.caseInsensitiveMatchForDuplicates = YES;
        self.checkForCommonPasswords = YES;
        self.levenshteinSimilarityThreshold = 0.75f;
        self.minimumLength = kDefaultMinimumLength;
        self.checkForMinimumLength = NO;

        self.checkForSimilarPasswords = NO; // CPU Heavy
        self.checkHibp = NO; // Online Access
        
        self.lastKnownAuditIssueCount = nil;
        self.showAuditPopupNotifications = YES;
        self.hibpCaveatAccepted = NO;
        self.hibpCheckForNewBreachesIntervalSeconds = 24 * 60 * 60; // Once a day check for newly compromised passwords
        self.lastHibpOnlineCheck = nil;
        self.showCachedHibpHits = YES;
    }
        
    return self;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//

+ (instancetype)fromJsonSerializationDictionary:(NSDictionary *)jsonDictionary {
    DatabaseAuditorConfiguration* ret = DatabaseAuditorConfiguration.defaults;
    
    if (jsonDictionary[@"auditInBackground"] != nil ) ret.auditInBackground = ((NSNumber*)(jsonDictionary[@"auditInBackground"])).boolValue;
    if (jsonDictionary[@"checkForNoPasswords"] != nil ) ret.checkForNoPasswords = ((NSNumber*)(jsonDictionary[@"checkForNoPasswords"])).boolValue;
    if (jsonDictionary[@"checkForDuplicatedPasswords"] != nil ) ret.checkForDuplicatedPasswords = ((NSNumber*)(jsonDictionary[@"checkForDuplicatedPasswords"])).boolValue;
    if (jsonDictionary[@"caseInsensitiveMatchForDuplicates"] != nil ) ret.caseInsensitiveMatchForDuplicates = ((NSNumber*)(jsonDictionary[@"caseInsensitiveMatchForDuplicates"])).boolValue;
    if (jsonDictionary[@"checkForCommonPasswords"] != nil ) ret.checkForCommonPasswords = ((NSNumber*)(jsonDictionary[@"checkForCommonPasswords"])).boolValue;
    if (jsonDictionary[@"checkForSimilarPasswords"] != nil ) ret.checkForSimilarPasswords = ((NSNumber*)(jsonDictionary[@"checkForSimilarPasswords"])).boolValue;
    if (jsonDictionary[@"levenshteinSimilarityThreshold"] != nil ) ret.levenshteinSimilarityThreshold = ((NSNumber*)(jsonDictionary[@"levenshteinSimilarityThreshold"])).doubleValue;
    if (jsonDictionary[@"minimumLength"] != nil ) ret.minimumLength = ((NSNumber*)(jsonDictionary[@"minimumLength"])).unsignedIntegerValue;
    if (jsonDictionary[@"checkForMinimumLength"] != nil ) ret.checkForMinimumLength = ((NSNumber*)(jsonDictionary[@"checkForMinimumLength"])).boolValue;
    if (jsonDictionary[@"checkHibp"] != nil ) ret.checkHibp = ((NSNumber*)(jsonDictionary[@"checkHibp"])).boolValue;
    if (jsonDictionary[@"showAuditPopupNotifications"] != nil ) ret.showAuditPopupNotifications = ((NSNumber*)(jsonDictionary[@"showAuditPopupNotifications"])).boolValue;
    if (jsonDictionary[@"hibpCaveatAccepted"] != nil ) ret.hibpCaveatAccepted = ((NSNumber*)(jsonDictionary[@"hibpCaveatAccepted"])).boolValue;
    if (jsonDictionary[@"hibpCheckForNewBreachesIntervalSeconds"] != nil ) ret.hibpCheckForNewBreachesIntervalSeconds = ((NSNumber*)(jsonDictionary[@"hibpCheckForNewBreachesIntervalSeconds"])).unsignedIntegerValue;
    if (jsonDictionary[@"showCachedHibpHits"] != nil ) ret.showCachedHibpHits = ((NSNumber*)(jsonDictionary[@"showCachedHibpHits"])).boolValue;
    if (jsonDictionary[@"lastHibpOnlineCheck"] != nil ) ret.lastHibpOnlineCheck = [NSDate dateWithTimeIntervalSinceReferenceDate:((NSNumber*)(jsonDictionary[@"lastHibpOnlineCheck"])).doubleValue];
    if (jsonDictionary[@"lastKnownAuditIssueCount"] != nil ) ret.lastKnownAuditIssueCount = ((NSNumber*)(jsonDictionary[@"lastKnownAuditIssueCount"]));
    
    return ret;
}

- (NSDictionary *)getJsonSerializationDictionary {
    NSMutableDictionary *ret = [NSMutableDictionary dictionaryWithDictionary:@{
        @"auditInBackground" : @(self.auditInBackground),
        @"checkForNoPasswords" : @(self.checkForNoPasswords),
        @"checkForDuplicatedPasswords" : @(self.checkForDuplicatedPasswords),
        @"caseInsensitiveMatchForDuplicates" : @(self.caseInsensitiveMatchForDuplicates),
        @"checkForCommonPasswords" : @(self.checkForCommonPasswords),
        @"checkForSimilarPasswords" : @(self.checkForSimilarPasswords),
        @"levenshteinSimilarityThreshold" : @(self.levenshteinSimilarityThreshold),
        @"minimumLength" : @(self.minimumLength),
        @"checkForMinimumLength" : @(self.checkForMinimumLength),
        @"checkHibp" : @(self.checkHibp),
        @"showAuditPopupNotifications" : @(self.showAuditPopupNotifications),
        @"hibpCaveatAccepted" : @(self.hibpCaveatAccepted),
        @"hibpCheckForNewBreachesIntervalSeconds" : @(self.hibpCheckForNewBreachesIntervalSeconds),
        @"showCachedHibpHits" : @(self.showCachedHibpHits),
    }];

    if( self.lastHibpOnlineCheck != nil) {
        ret[@"lastHibpOnlineCheck"] = @(self.lastHibpOnlineCheck.timeIntervalSinceReferenceDate);
    }
    
    if( self.lastKnownAuditIssueCount != nil) {
        ret[@"lastKnownAuditIssueCount"] = self.lastKnownAuditIssueCount;
    }

    return ret;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Legacy Serialization - Remove eventually

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

        if ([coder containsValueForKey:@"checkHibp"]) {
            self.checkHibp = [coder decodeBoolForKey:@"checkHibp"];
        }
        
        if ([coder containsValueForKey:@"lastKnownAuditIssueCount"]) {
            self.lastKnownAuditIssueCount = [coder decodeObjectForKey:@"lastKnownAuditIssueCount"];
        }
        
        if ([coder containsValueForKey:@"showAuditPopupNotifications"]) {
            self.showAuditPopupNotifications = [coder decodeBoolForKey:@"showAuditPopupNotifications"];
        }
        
        if ([coder containsValueForKey:@"hibpCaveatShown"]) {
            self.hibpCaveatAccepted = [coder decodeBoolForKey:@"hibpCaveatShown"];
        }
        
        if ([coder containsValueForKey:@"hibpCheckForNewBreachesIntervalSeconds"]) {
            self.hibpCheckForNewBreachesIntervalSeconds = [coder decodeIntegerForKey:@"hibpCheckForNewBreachesIntervalSeconds"];
        }
        
        if ([coder containsValueForKey:@"lastHibpOnlineCheck"]) {
            self.lastHibpOnlineCheck = [coder decodeObjectForKey:@"lastHibpOnlineCheck"];
        }
        
        if ([coder containsValueForKey:@"showCachedHibpHits"]) {
            self.showCachedHibpHits = [coder decodeBoolForKey:@"showCachedHibpHits"];
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
    [coder encodeBool:self.checkHibp forKey:@"checkHibp"];
    [coder encodeObject:self.lastKnownAuditIssueCount forKey:@"lastKnownAuditIssueCount"];
    [coder encodeBool:self.showAuditPopupNotifications forKey:@"showAuditPopupNotifications"];
    [coder encodeBool:self.hibpCaveatAccepted forKey:@"hibpCaveatShown"];
    [coder encodeInteger:self.hibpCheckForNewBreachesIntervalSeconds forKey:@"hibpCheckForNewBreachesIntervalSeconds"];
    [coder encodeObject:self.lastHibpOnlineCheck forKey:@"lastHibpOnlineCheck"];
    [coder encodeBool:self.showCachedHibpHits forKey:@"showCachedHibpHits"];
}

@end
