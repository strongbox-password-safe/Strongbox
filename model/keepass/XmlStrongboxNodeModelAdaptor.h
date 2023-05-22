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
#import "KeePassAttachmentAbstractionLayer.h"

NS_ASSUME_NONNULL_BEGIN

@interface XmlStrongboxNodeModelAdaptor : NSObject

- (nullable KeePassGroup*)toKeePassModel:(Node*)rootNode
                                 context:(XmlProcessingContext*)context
                   minimalAttachmentPool:(NSArray<KeePassAttachmentAbstractionLayer*>*_Nullable*_Nullable)minimalAttachmentPool
                                iconPool:(NSDictionary<NSUUID*, NodeIcon*>*)iconPool
                                   error:(NSError**)error;

- (nullable KeePassGroup*)toKeePassModel:(Node*)rootNode context:(XmlProcessingContext*)context error:(NSError**)error;

- (nullable Node*)toStrongboxModel:(KeePassGroup*)existingXmlRoot
                    error:(NSError**)error;

- (nullable Node*)toStrongboxModel:(KeePassGroup*)existingXmlRoot
                   attachmentsPool:(NSArray<KeePassAttachmentAbstractionLayer *> *)attachmentsPool
                    customIconPool:(NSDictionary<NSUUID *, NodeIcon *> *)customIconPool
                             error:(NSError**)error;

@end

NS_ASSUME_NONNULL_END
