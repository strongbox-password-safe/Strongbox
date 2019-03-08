//
//  GenericTextIntegerElementHandler.h
//  Strongbox
//
//  Created by Mark on 08/03/2019.
//  Copyright © 2019 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "BaseXmlDomainObjectHandler.h"

NS_ASSUME_NONNULL_BEGIN

@interface GenericTextIntegerElementHandler :  BaseXmlDomainObjectHandler

- (instancetype)initWithXmlElementName:(NSString*)xmlElementName context:(XmlProcessingContext*)context NS_DESIGNATED_INITIALIZER;

@property NSInteger integer;

@end

NS_ASSUME_NONNULL_END
