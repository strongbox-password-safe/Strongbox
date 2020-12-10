//
//  Meta.h
//  Strongbox
//
//  Created by Mark on 18/10/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
//

#import "BaseXmlDomainObjectHandler.h"
#import "V3BinariesList.h"
#import "CustomIconList.h"
#import "CustomData.h"

NS_ASSUME_NONNULL_BEGIN

@interface Meta : BaseXmlDomainObjectHandler
 
- (instancetype)initWithContext:(XmlProcessingContext*)context;
- (instancetype)initWithDefaultsAndInstantiatedChildren:(XmlProcessingContext*)context;

@property (nonatomic) NSString *generator;
@property (nonatomic, nullable) NSString* headerHash;
@property (nonatomic, nullable) NSNumber *historyMaxItems;
@property (nonatomic, nullable) NSNumber *historyMaxSize;

@property BOOL recycleBinEnabled;
@property NSUUID* recycleBinGroup;
@property NSDate* recycleBinChanged;

@property (nonatomic) V3BinariesList *v3binaries;
@property (nonatomic) CustomIconList *customIconList;
@property (nonatomic, nullable) CustomData* customData;

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






















@end

NS_ASSUME_NONNULL_END
