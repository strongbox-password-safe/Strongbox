//
//  XmlStrongBoxModelAdaptor.h
//  Strongbox
//
//  Created by Mark on 23/10/2018.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "RootXmlDomainObject.h"
#import "Node.h"
#import "KeePassDatabaseWideProperties.h"
#import "UnifiedDatabaseMetadata.h"

NS_ASSUME_NONNULL_BEGIN

@interface KeePassXmlModelAdaptor : NSObject

- (nullable RootXmlDomainObject*)toKeePassModel:(Node*)rootNode
                             databaseProperties:(KeePassDatabaseWideProperties*)databaseProperties
                                        context:(XmlProcessingContext*)context
                                          error:(NSError **)error;

- (nullable RootXmlDomainObject*)toKeePassModel:(Node*)rootNode
                             databaseProperties:(KeePassDatabaseWideProperties*)databaseProperties
                                        context:(XmlProcessingContext*)context
                          minimalAttachmentPool:(NSArray<KeePassAttachmentAbstractionLayer*>*_Nullable*_Nullable)minimalAttachmentPool
                                       iconPool:(NSDictionary<NSUUID*, NodeIcon*>*)iconPool
                                          error:(NSError **)error;

+ (Node*_Nullable)toStrongboxModel:(RootXmlDomainObject*)xmlRoot
                             error:(NSError**)error;

+ (Node*_Nullable)toStrongboxModel:(RootXmlDomainObject*)xmlRoot
                       attachments:(NSArray<KeePassAttachmentAbstractionLayer *> *)attachments
                    customIconPool:(NSDictionary<NSUUID *, NodeIcon*> *)customIconPool
                             error:(NSError**)error;

+ (UnifiedDatabaseMetadata*)getMetadata:(Meta*_Nullable)meta format:(DatabaseFormat)format;
+ (NSDictionary<NSUUID*, NSDate*>*)getDeletedObjects:(RootXmlDomainObject*)existingRootXmlDocument;
+ (NSDictionary<NSUUID*, NodeIcon*>*)getCustomIcons:(Meta*_Nullable)meta;
+ (NSArray<KeePassAttachmentAbstractionLayer*>*)getV3Attachments:(RootXmlDomainObject*)xmlDoc;

@end

NS_ASSUME_NONNULL_END
