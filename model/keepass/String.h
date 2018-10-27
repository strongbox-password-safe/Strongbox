//
//  String.h
//  Strongbox
//
//  Created by Mark on 17/10/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "BaseXmlDomainObjectHandler.h"
#import "GenericTextStringElementHandler.h"

NS_ASSUME_NONNULL_BEGIN

@interface String : BaseXmlDomainObjectHandler

- (instancetype)initWithProtectedValue:(BOOL)protected;

@property (nonatomic) GenericTextStringElementHandler *key;
@property (nonatomic) GenericTextStringElementHandler *value;

@end

NS_ASSUME_NONNULL_END
