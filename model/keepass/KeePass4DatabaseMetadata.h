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

@property NSString *generator;
@property KdfParameters *kdfParameters;
@property NSUUID* cipherUuid;
@property uint32_t innerRandomStreamId;
@property uint32_t compressionFlags;
@property NSString* version;

- (BasicOrderedDictionary<NSString*, NSString*>*)kvpForUi;

@end

NS_ASSUME_NONNULL_END
