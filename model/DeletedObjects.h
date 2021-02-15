//
//  DeletedObjects.h
//  Strongbox
//
//  Created by Strongbox on 18/05/2020.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "DeletedObject.h"

NS_ASSUME_NONNULL_BEGIN

@interface DeletedObjects : BaseXmlDomainObjectHandler

- (instancetype)initWithContext:(XmlProcessingContext*)context;

@property NSMutableArray<DeletedObject*>* deletedObjects;


@end

NS_ASSUME_NONNULL_END
