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

NS_ASSUME_NONNULL_BEGIN

@interface XmlStrongBoxModelAdaptor : NSObject

- (nullable Node*)fromXmlModelToStrongboxModel:(RootXmlDomainObject*)existingRootXmlDocument
                                error:(NSError**)error;

- (nullable RootXmlDomainObject*)toXmlModelFromStrongboxModel:(Node*)rootNode
                                           databaseProperties:(KeePassDatabaseWideProperties*)databaseProperties
                                                      context:(XmlProcessingContext*)context
                                               error:(NSError **)error;

@end

NS_ASSUME_NONNULL_END
