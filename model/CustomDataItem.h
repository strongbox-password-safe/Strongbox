//
//  CustomDataItem.h
//  Strongbox
//
//  Created by Strongbox on 02/11/2020.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "BaseXmlDomainObjectHandler.h"

NS_ASSUME_NONNULL_BEGIN

@interface CustomDataItem : BaseXmlDomainObjectHandler

- (instancetype)initWithContext:(XmlProcessingContext*)context;

@property NSString* key;
@property NSString* value;
@property (nullable) NSDate* modified; 

@end

NS_ASSUME_NONNULL_END
