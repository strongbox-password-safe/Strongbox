//
//  RootXmlDomainObject.h
//  Strongbox
//
//  Created by Mark on 18/10/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "BaseXmlDomainObjectHandler.h"
#import "KeePassFile.h"

NS_ASSUME_NONNULL_BEGIN

@interface RootXmlDomainObject : BaseXmlDomainObjectHandler

- (instancetype)initWithContext:(XmlProcessingContext*)context;
- (instancetype)initWithDefaultsAndInstantiatedChildren:(XmlProcessingContext*)context;

@property (nonatomic, readonly) KeePassFile* keePassFile;

- (XmlTree *)generateXmlTree;

@end

NS_ASSUME_NONNULL_END
