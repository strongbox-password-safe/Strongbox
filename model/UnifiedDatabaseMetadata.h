//
//  AbstractSafeMetadata.h
//  Strongbox
//
//  Created by Mark on 23/10/2018.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "MutableOrderedDictionary.h"
#import "KdfParameters.h"
#import "DatabaseFormat.h"
#import "ValueWithModDate.h"

NS_ASSUME_NONNULL_BEGIN

extern NSString* const kKdb4DefaultFileVersion;
extern const uint32_t kKdb4DefaultInnerRandomStreamId;
extern NSString* const kKP3DefaultFileVersion;
extern const uint32_t kKP3DefaultInnerRandomStreamId;

@interface UnifiedDatabaseMetadata : NSObject

+ (instancetype)withDefaultsForFormat:(DatabaseFormat)format;

- (instancetype)init NS_UNAVAILABLE;

- (instancetype)clone;

- (MutableOrderedDictionary<NSString *,NSString *> *)filteredKvpForUIWithFormat:(DatabaseFormat)format;

@property (nonatomic, nullable) NSString* version;
@property (nonatomic, nullable) NSString *generator;

@property (nullable, nonatomic) NSDate* recycleBinChanged;
@property (nullable, nonatomic) NSUUID* recycleBinGroup;
@property BOOL recycleBinEnabled;

@property (nonatomic, nullable) NSNumber *historyMaxItems;
@property (nonatomic, nullable) NSNumber *historyMaxSize;

@property (nonatomic) NSMutableDictionary<NSString*, ValueWithModDate*>* customData;

@property NSDate* settingsChanged;
@property (nonatomic) NSString *databaseName;
@property NSDate* databaseNameChanged;
@property (nonatomic) NSString *databaseDescription;
@property NSDate* databaseDescriptionChanged;
@property (nonatomic) NSString *defaultUserName;
@property NSDate* defaultUserNameChanged;
@property (nonatomic) NSString *color;
@property NSUUID* entryTemplatesGroup;
@property NSDate* entryTemplatesGroupChanged;

@property (nullable) NSNumber* maintenanceHistoryDays;
@property (nullable) NSDate*  masterKeyChanged;
@property (nullable) NSNumber* masterKeyChangeRec;
@property (nullable) NSNumber* masterKeyChangeForce;
@property (nullable) NSNumber*  masterKeyChangeForceOnce;
@property (nullable) NSUUID* lastSelectedGroup;
@property (nullable) NSUUID*  lastTopVisibleGroup;
@property (nullable) NSNumber* protectTitle;
@property (nullable) NSNumber* protectUsername;
@property (nullable) NSNumber* protectPassword;
@property (nullable) NSNumber* protectURL;
@property (nullable) NSNumber* protectNotes;



@property (nonatomic) uint32_t compressionFlags;
@property (nonatomic) uint32_t innerRandomStreamId;
@property NSUUID* cipherUuid;



@property KdfParameters *kdfParameters;



@property (nonatomic, nullable) NSDate *lastUpdateTime;
@property (nonatomic, nullable) NSString *lastUpdateUser;
@property (nonatomic, nullable) NSString *lastUpdateHost;
@property (nonatomic, nullable) NSString *lastUpdateApp;



@property uint32_t flags;
@property uint32_t versionInt;



@property (nullable) NSObject* adaptorTag; 



@property (nonatomic) uint64_t kdfIterations;

@end

NS_ASSUME_NONNULL_END
