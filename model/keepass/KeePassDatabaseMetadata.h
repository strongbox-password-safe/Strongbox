//
//  KeePassDatabaseMetadata.h
//  Strongbox
//
//  Created by Mark on 23/10/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "AbstractDatabaseMetadata.h"

NS_ASSUME_NONNULL_BEGIN

@interface KeePassDatabaseMetadata : NSObject<AbstractDatabaseMetadata>

@property (nonatomic) NSString* generator;
@property (nonatomic) NSString* version;
@property (nonatomic) uint32_t compressionFlags;
@property (nonatomic) uint64_t transformRounds;
@property (nonatomic) uint32_t innerRandomStreamId;

// TODO: Memory Protection elements?

@end

NS_ASSUME_NONNULL_END
