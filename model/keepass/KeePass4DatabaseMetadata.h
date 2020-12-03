//
//  KeePass4DatabaseMetadata.h
//  Strongbox
//
//  Created by Mark on 30/10/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "KdfParameters.h"
#import "AbstractDatabaseMetadata.h"

NS_ASSUME_NONNULL_BEGIN

@interface KeePass4DatabaseMetadata : NSObject<AbstractDatabaseMetadata>

@property (nonatomic, nullable) NSString* generator;
@property (nonatomic, nullable) NSString* version;

@property (nullable, nonatomic) NSDate* recycleBinChanged;
@property (nullable, nonatomic) NSUUID* recycleBinGroup;
@property BOOL recycleBinEnabled;

@property (nonatomic, nullable) NSNumber* historyMaxItems;
@property (nonatomic, nullable) NSNumber* historyMaxSize;

@property (nonatomic) MutableOrderedDictionary* customData;

@property KdfParameters *kdfParameters;
@property NSUUID* cipherUuid;
@property uint32_t innerRandomStreamId;
@property uint32_t compressionFlags;

- (MutableOrderedDictionary<NSString*, NSString*>*)kvpForUi;

@end

NS_ASSUME_NONNULL_END
