//
//  CustomData.h
//  Strongbox
//
//  Created by Strongbox on 02/11/2020.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "BaseXmlDomainObjectHandler.h"

NS_ASSUME_NONNULL_BEGIN

@interface CustomData : BaseXmlDomainObjectHandler

// <CustomData>






- (instancetype)initWithContext:(XmlProcessingContext*)context;

@property NSMutableDictionary<NSString*, NSString*> *dictionary;

@end

NS_ASSUME_NONNULL_END
