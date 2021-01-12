//
//  XmlStrongBoxModelAdaptor.h
//  Strongbox
//
//  Created by Mark on 23/10/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
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
                                        minimalAttachmentPool:(NSArray<DatabaseAttachment*>*_Nullable*_Nullable)minimalAttachmentPool
                                                        error:(NSError **)error;

+ (Node*_Nullable)toStrongboxModel:(RootXmlDomainObject*)xmlRoot
                         error:(NSError**)error;

+ (Node*_Nullable)toStrongboxModel:(RootXmlDomainObject*)xmlRoot
                   attachments:(NSArray<DatabaseAttachment *> *)attachments
                customIconPool:(NSDictionary<NSUUID *,NSData *> *)customIconPool
                         error:(NSError**)error;

+ (UnifiedDatabaseMetadata*)getMetadata:(Meta*)meta format:(DatabaseFormat)format;
+ (NSDictionary<NSUUID*, NSDate*>*)getDeletedObjects:(RootXmlDomainObject*)existingRootXmlDocument;
+ (NSMutableDictionary<NSUUID*, NSData*>*)getCustomIcons:(Meta*_Nullable)meta;
+ (NSArray<DatabaseAttachment*>*)getV3Attachments:(RootXmlDomainObject*)xmlDoc;

@end

NS_ASSUME_NONNULL_END
