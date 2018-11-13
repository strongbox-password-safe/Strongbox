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
@property uint32_t version;
@property uint32_t transformRounds;

- (BasicOrderedDictionary<NSString*, NSString*>*)kvpForUi;

@end

NS_ASSUME_NONNULL_END
