//
//  DecryptionParameters.h
//  Strongbox-iOS
//
//  Created by Mark on 16/10/2018.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface DecryptionParameters : NSObject

@property (nonatomic) NSData *transformSeed;
@property (nonatomic) uint64_t transformRounds;
@property (nonatomic) NSData *masterSeed;
@property (nonatomic) NSData *encryptionIv;
@property (nonatomic) NSData *streamStartBytes;
@property (nonatomic) uint32_t compressionFlags;
@property (nonatomic) uint32_t innerRandomStreamId;
@property (nonatomic) NSData *protectedStreamKey;
@property (nonatomic) NSUUID *cipherId;

@end

NS_ASSUME_NONNULL_END
