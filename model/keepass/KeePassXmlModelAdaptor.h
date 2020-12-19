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

- (nullable RootXmlDomainObject*)toXmlModelFromStrongboxModel:(Node*)rootNode
                                           databaseProperties:(KeePassDatabaseWideProperties*)databaseProperties
                                                      context:(XmlProcessingContext*)context
                                               error:(NSError **)error;

+ (Node*_Nullable)getNodeModel:(RootXmlDomainObject*)xmlRoot error:(NSError**)error;
+ (UnifiedDatabaseMetadata*)getMetadata:(Meta*)meta format:(DatabaseFormat)format;
+ (NSDictionary<NSUUID*, NSDate*>*)getDeletedObjects:(RootXmlDomainObject*)existingRootXmlDocument;
+ (NSMutableDictionary<NSUUID*, NSData*>*)getCustomIcons:(Meta*)meta;
+ (NSArray<DatabaseAttachment*>*)getV3Attachments:(RootXmlDomainObject*)xmlDoc;

@end

NS_ASSUME_NONNULL_END
