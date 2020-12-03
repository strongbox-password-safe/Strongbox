//
//  Kdb1DatabaseMetadata.h
//  Strongbox
//
//  Created by Mark on 09/11/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "AbstractDatabaseMetadata.h"

NS_ASSUME_NONNULL_BEGIN

@interface Kdb1DatabaseMetadata : NSObject<AbstractDatabaseMetadata>

@property uint32_t flags;
@property uint32_t versionInt;
@property uint32_t transformRounds;

- (MutableOrderedDictionary<NSString*, NSString*>*)kvpForUi;

@property (nonatomic, nullable) NSString* version;
@property (nonatomic, nullable) NSString *generator;
@property (nullable, nonatomic) NSDate* recycleBinChanged;
@property (nullable, nonatomic) NSUUID* recycleBinGroup;
@property BOOL recycleBinEnabled;
@property (nonatomic, nullable) NSNumber *historyMaxItems;
@property (nonatomic, nullable) NSNumber *historyMaxSize;
@property (nonatomic) MutableOrderedDictionary* customData;

@end

NS_ASSUME_NONNULL_END
