//
//  KeePassDatabaseMetadata.h
//  Strongbox
//
//  Created by Mark on 23/10/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "AbstractDatabaseMetadata.h"
#import "MutableOrderedDictionary.h"

NS_ASSUME_NONNULL_BEGIN

@interface KeePassDatabaseMetadata : NSObject<AbstractDatabaseMetadata>

@property (nonatomic, nullable) NSString* generator;
@property (nonatomic, nullable) NSString* version;

@property (nullable, nonatomic) NSDate* recycleBinChanged;
@property (nullable, nonatomic) NSUUID* recycleBinGroup;
@property BOOL recycleBinEnabled;

@property (nonatomic, nullable) NSNumber* historyMaxItems;
@property (nonatomic, nullable) NSNumber* historyMaxSize;

@property (nonatomic) MutableOrderedDictionary* customData;

@property (nonatomic) uint32_t compressionFlags;
@property (nonatomic) uint64_t transformRounds;
@property (nonatomic) uint32_t innerRandomStreamId;
@property NSUUID* cipherUuid;

@end

NS_ASSUME_NONNULL_END
