//
//  Kdbx4SerializationData.h
//  Strongbox
//
//  Created by Mark on 30/10/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "KdfParameters.h"
#import "DatabaseAttachment.h"

NS_ASSUME_NONNULL_BEGIN

@interface Kdbx4SerializationData : NSObject

@property NSString* fileVersion;
@property uint32_t compressionFlags;
@property uint32_t innerRandomStreamId;
@property NSData* innerRandomStreamKey;
@property NSDictionary<NSNumber*, NSObject*> *extraUnknownHeaders;
@property NSString* xml;
@property KdfParameters *kdfParameters;
@property NSUUID* cipherUuid;
@property NSArray<DatabaseAttachment*>* attachments;

@end

NS_ASSUME_NONNULL_END
