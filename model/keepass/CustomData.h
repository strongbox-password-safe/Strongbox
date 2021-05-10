//
//  CustomData.h
//  Strongbox
//
//  Created by Strongbox on 02/11/2020.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "BaseXmlDomainObjectHandler.h"
#import "ValueWithModDate.h"

NS_ASSUME_NONNULL_BEGIN

@interface CustomData : BaseXmlDomainObjectHandler








- (instancetype)initWithContext:(XmlProcessingContext*)context;

@property NSMutableDictionary<NSString*, ValueWithModDate*> *dictionary;

@end

NS_ASSUME_NONNULL_END
