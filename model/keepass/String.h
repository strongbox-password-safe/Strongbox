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
- (instancetype)initWithKey:(NSString *)key value:(NSString *)value protected:(BOOL)protected context:(XmlProcessingContext*)context;

@property NSString* key;
@property NSString* value;
@property BOOL protected;

@end

NS_ASSUME_NONNULL_END
