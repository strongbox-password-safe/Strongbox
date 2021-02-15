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

NS_ASSUME_NONNULL_BEGIN

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

@property (nonatomic) NSMutableDictionary* customData;

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



@property (nonatomic) uint32_t compressionFlags;
@property (nonatomic) uint64_t transformRounds;
@property (nonatomic) uint32_t innerRandomStreamId;
@property NSUUID* cipherUuid;



@property KdfParameters *kdfParameters;



@property (nonatomic, nullable) NSDate *lastUpdateTime;
@property (nonatomic, nullable) NSString *lastUpdateUser;
@property (nonatomic, nullable) NSString *lastUpdateHost;
@property (nonatomic, nullable) NSString *lastUpdateApp;
@property (nonatomic) NSInteger keyStretchIterations;



@property uint32_t flags;
@property uint32_t versionInt;



@property (nullable) NSObject* adaptorTag; 

@end

NS_ASSUME_NONNULL_END
