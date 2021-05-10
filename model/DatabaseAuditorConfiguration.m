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
        self.showAuditPopupNotifications = YES;
        self.hibpCaveatAccepted = NO;
        self.hibpCheckForNewBreachesIntervalSeconds = 24 * 60 * 60; 
        self.lastHibpOnlineCheck = nil;
        self.showCachedHibpHits = YES;
    }
        
    return self;
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
    if (jsonDictionary[@"showAuditPopupNotifications"] != nil ) ret.showAuditPopupNotifications = ((NSNumber*)(jsonDictionary[@"showAuditPopupNotifications"])).boolValue;
    if (jsonDictionary[@"hibpCaveatAccepted"] != nil ) ret.hibpCaveatAccepted = ((NSNumber*)(jsonDictionary[@"hibpCaveatAccepted"])).boolValue;
    if (jsonDictionary[@"hibpCheckForNewBreachesIntervalSeconds"] != nil ) ret.hibpCheckForNewBreachesIntervalSeconds = ((NSNumber*)(jsonDictionary[@"hibpCheckForNewBreachesIntervalSeconds"])).unsignedIntegerValue;
    if (jsonDictionary[@"showCachedHibpHits"] != nil ) ret.showCachedHibpHits = ((NSNumber*)(jsonDictionary[@"showCachedHibpHits"])).boolValue;
    if (jsonDictionary[@"lastHibpOnlineCheck"] != nil ) ret.lastHibpOnlineCheck = [NSDate dateWithTimeIntervalSinceReferenceDate:((NSNumber*)(jsonDictionary[@"lastHibpOnlineCheck"])).doubleValue];
    if (jsonDictionary[@"lastKnownAuditIssueCount"] != nil ) ret.lastKnownAuditIssueCount = ((NSNumber*)(jsonDictionary[@"lastKnownAuditIssueCount"]));
    if (jsonDictionary[@"lowEntropyThreshold"] != nil ) ret.lowEntropyThreshold = ((NSNumber*)(jsonDictionary[@"lowEntropyThreshold"])).unsignedIntegerValue;

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
        @"showAuditPopupNotifications" : @(self.showAuditPopupNotifications),
        @"hibpCaveatAccepted" : @(self.hibpCaveatAccepted),
        @"hibpCheckForNewBreachesIntervalSeconds" : @(self.hibpCheckForNewBreachesIntervalSeconds),
        @"showCachedHibpHits" : @(self.showCachedHibpHits),
        @"lowEntropyThreshold" : @(self.lowEntropyThreshold),
    }];

    if( self.lastHibpOnlineCheck != nil) {
        ret[@"lastHibpOnlineCheck"] = @(self.lastHibpOnlineCheck.timeIntervalSinceReferenceDate);
    }
    
    if( self.lastKnownAuditIssueCount != nil) {
        ret[@"lastKnownAuditIssueCount"] = self.lastKnownAuditIssueCount;
    }

    return ret;
}

@end
