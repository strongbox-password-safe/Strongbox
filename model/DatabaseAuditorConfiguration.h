//
//  DatabaseAuditorConfiguration.h
//  Strongbox
//
//  Created by Mark on 17/04/2020.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface DatabaseAuditorConfiguration : NSObject

+ (instancetype)defaults;

+ (instancetype)fromJsonSerializationDictionary:(NSDictionary*)jsonDictionary;
- (NSDictionary *)getJsonSerializationDictionary;

@property BOOL auditInBackground;
@property BOOL checkForNoPasswords;
@property BOOL checkForTwoFactorAvailable;
@property BOOL checkForDuplicatedPasswords;
@property BOOL caseInsensitiveMatchForDuplicates;
@property BOOL checkForCommonPasswords;
@property BOOL checkForLowEntropy;
@property NSUInteger lowEntropyThreshold;

@property BOOL checkForSimilarPasswords;
@property double levenshteinSimilarityThreshold;

@property BOOL checkForMinimumLength;
@property NSUInteger minimumLength;

@property BOOL checkHibp;

@property (nullable) NSNumber* lastKnownAuditIssueCount;
@property BOOL showAuditPopupNotifications;
@property BOOL hibpCaveatAccepted;

@property NSUInteger hibpCheckForNewBreachesIntervalSeconds;
@property NSTimeInterval lastDuration;

@property (nullable) NSDate* lastHibpOnlineCheck;
@property (readonly) BOOL showCachedHibpHits;

@property BOOL excludeShortNumericPINCodes;

@end

NS_ASSUME_NONNULL_END
