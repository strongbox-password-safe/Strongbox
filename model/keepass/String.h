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

// <String>
// <Key>Password</Key>
// <Value Protected="True">5Q==</Value>
// </String>

@interface String : BaseXmlDomainObjectHandler

- (instancetype)initWithContext:(XmlProcessingContext*)context;
- (instancetype)initWithProtectedValue:(BOOL)protected context:(XmlProcessingContext*)context;

@property (nonatomic) GenericTextStringElementHandler *key;
@property (nonatomic) GenericTextStringElementHandler *value;

@end

NS_ASSUME_NONNULL_END
