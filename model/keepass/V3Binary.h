//
//  V3Binary.h
//  Strongbox
//
//  Created by Mark on 02/11/2018.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "BaseXmlDomainObjectHandler.h"
#import "DatabaseAttachment.h"

NS_ASSUME_NONNULL_BEGIN

@interface V3Binary : BaseXmlDomainObjectHandler

- (instancetype)initWithContext:(XmlProcessingContext*)context dbAttachment:(DatabaseAttachment*)dbAttachment;

- (void)onCompletedWithStrangeProtectedAttribute:(NSData*)data;

@property int id;
@property BOOL compressed;

@property DatabaseAttachment* dbAttachment;

@end

NS_ASSUME_NONNULL_END
