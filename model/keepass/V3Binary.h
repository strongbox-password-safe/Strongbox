//
//  V3Binary.h
//  Strongbox
//
//  Created by Mark on 02/11/2018.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "BaseXmlDomainObjectHandler.h"
#import "KeePassAttachmentAbstractionLayer.h"

NS_ASSUME_NONNULL_BEGIN

@interface V3Binary : BaseXmlDomainObjectHandler

- (instancetype)initWithContext:(XmlProcessingContext*)context dbAttachment:(KeePassAttachmentAbstractionLayer*)dbAttachment;

- (void)onCompletedWithStrangeProtectedAttribute:(NSData*)data;

@property int id;
@property BOOL compressed;

@property KeePassAttachmentAbstractionLayer* dbAttachment;

@end

NS_ASSUME_NONNULL_END
