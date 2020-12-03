//
//  CustomData.h
//  Strongbox
//
//  Created by Strongbox on 02/11/2020.
//  Copyright © 2020 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "BaseXmlDomainObjectHandler.h"
#import "MutableOrderedDictionary.h"

NS_ASSUME_NONNULL_BEGIN

@interface CustomData : BaseXmlDomainObjectHandler








- (instancetype)initWithContext:(XmlProcessingContext*)context;

@property MutableOrderedDictionary<NSString*, NSString*> *orderedDictionary;

@end

NS_ASSUME_NONNULL_END
