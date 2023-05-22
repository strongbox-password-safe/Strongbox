//
//  SerializationData.h
//  StrongboxTests
//
//  Created by Mark on 17/10/2018.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "DecryptionParameters.h"
#import "KeePassAttachmentAbstractionLayer.h"
#import "RootXmlDomainObject.h"

NS_ASSUME_NONNULL_BEGIN

@interface SerializationData : NSObject

@property (nonatomic) uint32_t compressionFlags;
@property (nonatomic) uint32_t innerRandomStreamId;
@property (nonatomic) uint64_t transformRounds;
@property (nonatomic) NSData *protectedStreamKey;
@property (nonatomic) NSString *fileVersion;
@property (nonatomic) NSDictionary<NSNumber *,NSObject *>* extraUnknownHeaders;
@property (nonatomic) NSString* headerHash;
@property (nonatomic) NSUUID* cipherId;
@property RootXmlDomainObject* rootXmlObject;

@end

NS_ASSUME_NONNULL_END
