//
//  DatabaseAuditorConfiguration.h
//  Strongbox
//
//  Created by Mark on 17/04/2020.
//  Copyright © 2020 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface DatabaseAuditorConfiguration : NSObject

+ (instancetype)defaults;

+ (instancetype)fromJsonSerializationDictionary:(NSDictionary*)jsonDictionary;
- (NSDictionary *)getJsonSerializationDictionary;

@property BOOL auditInBackground;
@property BOOL checkForNoPasswords;
@property BOOL checkForDuplicatedPasswords;
@property BOOL caseInsensitiveMatchForDuplicates;
@property BOOL checkForCommonPasswords;

@property BOOL checkForSimilarPasswords;
@property double levenshteinSimilarityThreshold;

@property BOOL checkForMinimumLength;
@property NSUInteger minimumLength;

@property BOOL checkHibp;

@property (nullable) NSNumber* lastKnownAuditIssueCount;
@property BOOL showAuditPopupNotifications;
@property BOOL hibpCaveatAccepted;

@property NSUInteger hibpCheckForNewBreachesIntervalSeconds;
@property (nullable) NSDate* lastHibpOnlineCheck;
@property BOOL showCachedHibpHits;

@end

NS_ASSUME_NONNULL_END
