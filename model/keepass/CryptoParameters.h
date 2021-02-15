//
//  CryptoParameters.h
//  Strongbox
//
//  Created by Mark on 30/10/2018.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "KdfParameters.h"

NS_ASSUME_NONNULL_BEGIN

@interface CryptoParameters : NSObject

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initFromHeaders:(NSDictionary<NSNumber*, NSObject*>*)headerEntries NS_DESIGNATED_INITIALIZER;

@property NSUUID *cipherUuid;
@property KdfParameters *kdfParameters;
@property NSData* masterSeed;
@property NSData* iv;
@property uint32_t compressionFlags;

@end

NS_ASSUME_NONNULL_END
