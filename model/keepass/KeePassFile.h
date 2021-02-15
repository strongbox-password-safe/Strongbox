//
//  KeePassFile.h
//  Strongbox
//
//  Created by Mark on 17/10/2018.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "BaseXmlDomainObjectHandler.h"
#import "Meta.h"
#import "Root.h"

NS_ASSUME_NONNULL_BEGIN

@interface KeePassFile : BaseXmlDomainObjectHandler

- (instancetype)initWithContext:(XmlProcessingContext*)context;
- (instancetype)initWithDefaultsAndInstantiatedChildren:(XmlProcessingContext*)context;

@property (nonatomic, readonly) Meta* meta;
@property (nonatomic, readonly) Root* root;

@end

NS_ASSUME_NONNULL_END
