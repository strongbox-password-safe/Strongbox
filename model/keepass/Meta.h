//
//  Meta.h
//  Strongbox
//
//  Created by Mark on 18/10/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
//

#import "BaseXmlDomainObjectHandler.h"
#import "GenericTextStringElementHandler.h"

NS_ASSUME_NONNULL_BEGIN

@interface Meta : BaseXmlDomainObjectHandler

- (instancetype)initWithDefaultsAndInstantiatedChildren;

@property (nonatomic) GenericTextStringElementHandler *generator;
@property (nonatomic) GenericTextStringElementHandler *headerHash;

- (void)setHash:(NSString*)hash;

@end

NS_ASSUME_NONNULL_END
