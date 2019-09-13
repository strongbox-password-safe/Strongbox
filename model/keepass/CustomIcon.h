//
//  CustomIcon.h
//  Strongbox
//
//  Created by Mark on 11/11/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "BaseXmlDomainObjectHandler.h"

NS_ASSUME_NONNULL_BEGIN

@interface CustomIcon : BaseXmlDomainObjectHandler

- (instancetype)initWithContext:(XmlProcessingContext*)context;

@property (nonatomic) NSUUID* uuid;
@property (nonatomic) NSData* data;

@end

NS_ASSUME_NONNULL_END
