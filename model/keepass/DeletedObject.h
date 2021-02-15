//
//  DeletedObject.h
//  MacBox
//
//  Created by Strongbox on 14/05/2020.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "BaseXmlDomainObjectHandler.h"

NS_ASSUME_NONNULL_BEGIN

@interface DeletedObject : BaseXmlDomainObjectHandler

// <DeletedObject>




- (instancetype)initWithContext:(XmlProcessingContext*)context;

@property NSUUID* uuid;
@property NSDate* deletionTime;

@end

NS_ASSUME_NONNULL_END
