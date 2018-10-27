//
//  XmlStrongBoxModelAdaptor.h
//  Strongbox
//
//  Created by Mark on 23/10/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "RootXmlDomainObject.h"
#import "KeePassDatabaseMetadata.h"
#import "Node.h"
#import "KeepassMetaDataAndNodeModel.h"

NS_ASSUME_NONNULL_BEGIN

@interface XmlStrongBoxModelAdaptor : NSObject

- (nullable KeepassMetaDataAndNodeModel*)fromXmlModelToStrongboxModel:(nullable RootXmlDomainObject*)existingRootXmlDocument
                                                       error:(NSError**)error;

- (nullable RootXmlDomainObject*)toXmlModelFromStrongboxModel:(nullable KeepassMetaDataAndNodeModel*)metadataAndNodeModel
                             existingRootXmlDocument:(nullable RootXmlDomainObject*)existingRootXmlDocument
                                               error:(NSError**)error;

@end

NS_ASSUME_NONNULL_END
