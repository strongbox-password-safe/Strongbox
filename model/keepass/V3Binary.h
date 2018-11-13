//
//  V3Binary.h
//  Strongbox
//
//  Created by Mark on 02/11/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "BaseXmlDomainObjectHandler.h"

NS_ASSUME_NONNULL_BEGIN

@interface V3Binary : BaseXmlDomainObjectHandler

- (instancetype)initWithContext:(XmlProcessingContext*)context;

@property int id;
@property BOOL compressed;
@property NSData* data;

@end

NS_ASSUME_NONNULL_END
