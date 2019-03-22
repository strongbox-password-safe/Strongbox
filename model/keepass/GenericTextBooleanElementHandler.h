//
//  GenericTextBooleanElementHandler.h
//  Strongbox
//
//  Created by Mark on 20/03/2019.
//  Copyright © 2019 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "BaseXmlDomainObjectHandler.h"

NS_ASSUME_NONNULL_BEGIN

@interface GenericTextBooleanElementHandler :  BaseXmlDomainObjectHandler

- (instancetype)initWithXmlElementName:(NSString*)xmlElementName context:(XmlProcessingContext*)context NS_DESIGNATED_INITIALIZER;

@property BOOL booleanValue;

@end

NS_ASSUME_NONNULL_END
