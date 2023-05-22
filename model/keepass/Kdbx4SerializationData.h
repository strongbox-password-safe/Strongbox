//
//  Kdbx4SerializationData.h
//  Strongbox
//
//  Created by Mark on 30/10/2018.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "KdfParameters.h"
#import "KeePassAttachmentAbstractionLayer.h"
#import "RootXmlDomainObject.h"

NS_ASSUME_NONNULL_BEGIN

@interface Kdbx4SerializationData : NSObject

@property NSString* fileVersion;
@property uint32_t compressionFlags;
@property uint32_t innerRandomStreamId;
@property (nullable) NSData* innerRandomStreamKey;
@property NSDictionary<NSNumber*, NSObject*> *extraUnknownHeaders;
@property KdfParameters *kdfParameters;
@property NSUUID* cipherUuid;
@property NSArray<KeePassAttachmentAbstractionLayer*>* attachments;
@property RootXmlDomainObject* rootXmlObject;

@end

NS_ASSUME_NONNULL_END
