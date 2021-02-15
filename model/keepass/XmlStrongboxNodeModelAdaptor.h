//
//  KeePassXmlModelAdaptor.h
//  Strongbox-iOS
//
//  Created by Mark on 16/10/2018.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Node.h"
#import "SerializationData.h"
#import "KeePassGroup.h"
#import "DatabaseAttachment.h"

NS_ASSUME_NONNULL_BEGIN

@interface XmlStrongboxNodeModelAdaptor : NSObject

- (nullable KeePassGroup*)toKeePassModel:(Node*)rootNode
                            context:(XmlProcessingContext*)context
              minimalAttachmentPool:(NSArray<DatabaseAttachment*>*_Nullable*_Nullable)minimalAttachmentPool
                     customIconPool:(NSDictionary<NSUUID*, NSData*>*_Nullable*_Nullable)customIconPool
                              error:(NSError**)error;

- (nullable KeePassGroup*)toKeePassModel:(Node*)rootNode context:(XmlProcessingContext*)context error:(NSError**)error;

- (nullable Node*)toStrongboxModel:(KeePassGroup*)existingXmlRoot
                    error:(NSError**)error;

- (nullable Node*)toStrongboxModel:(KeePassGroup*)existingXmlRoot
          attachmentsPool:(NSArray<DatabaseAttachment *> *)attachmentsPool
           customIconPool:(NSDictionary<NSUUID *,NSData *> *)customIconPool
                    error:(NSError**)error;

@end

NS_ASSUME_NONNULL_END
