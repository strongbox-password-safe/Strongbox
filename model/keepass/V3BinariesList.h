//
//  V3BinariesList.h
//  Strongbox
//
//  Created by Mark on 02/11/2018.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "V3Binary.h"
#import "BaseXmlDomainObjectHandler.h"
NS_ASSUME_NONNULL_BEGIN

@interface V3BinariesList : BaseXmlDomainObjectHandler

- (instancetype)initWithContext:(XmlProcessingContext*)context;

@property NSMutableArray<V3Binary*>* binaries;

@end

NS_ASSUME_NONNULL_END
