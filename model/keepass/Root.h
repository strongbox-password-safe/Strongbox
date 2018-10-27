//
//  Root.h
//  Strongbox
//
//  Created by Mark on 20/10/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
//

#import "BaseXmlDomainObjectHandler.h"
#import "KeePassGroup.h"

NS_ASSUME_NONNULL_BEGIN

@interface Root : BaseXmlDomainObjectHandler

- (instancetype)initWithDefaultsAndInstantiatedChildren;

@property (nonatomic) KeePassGroup* rootGroup;

@end

NS_ASSUME_NONNULL_END
