//
//  Meta.h
//  Strongbox
//
//  Created by Mark on 18/10/2018.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import "BaseXmlDomainObjectHandler.h"
#import "V3BinariesList.h"
#import "CustomIconList.h"
#import "CustomData.h"
#import "MemoryProtection.h"

NS_ASSUME_NONNULL_BEGIN

@interface Meta : BaseXmlDomainObjectHandler
 
- (instancetype)initWithContext:(XmlProcessingContext*)context;
- (instancetype)initWithDefaultsAndInstantiatedChildren:(XmlProcessingContext*)context;

@property (nonatomic, nullable) NSString* headerHash;
@property NSDate* settingsChanged;
@property (nonatomic) NSString *generator;
@property (nonatomic) NSString *databaseName;
@property NSDate* databaseNameChanged;
@property (nonatomic) NSString *databaseDescription;
@property NSDate* databaseDescriptionChanged;
@property (nonatomic) NSString *defaultUserName;
@property NSDate* defaultUserNameChanged;
@property (nullable) NSNumber* maintenanceHistoryDays;
@property (nonatomic) NSString *color;
@property (nullable) NSDate*  masterKeyChanged;
@property (nullable) NSNumber* masterKeyChangeRec;
@property (nullable) NSNumber* masterKeyChangeForce;
@property (nullable) NSNumber*  masterKeyChangeForceOnce;
@property (nullable) MemoryProtection* memoryProtection;
@property (nonatomic) CustomIconList *customIconList;
@property BOOL recycleBinEnabled;
@property NSUUID* recycleBinGroup;
@property NSDate* recycleBinChanged;
@property NSUUID* entryTemplatesGroup;
@property NSDate* entryTemplatesGroupChanged;
@property (nonatomic, nullable) NSNumber *historyMaxItems;
@property (nonatomic, nullable) NSNumber *historyMaxSize;
@property (nullable) NSUUID* lastSelectedGroup;
@property (nullable) NSUUID*  lastTopVisibleGroup;
@property (nonatomic) V3BinariesList *v3binaries;
@property (nonatomic, nullable) CustomData* customData;

@end

NS_ASSUME_NONNULL_END
