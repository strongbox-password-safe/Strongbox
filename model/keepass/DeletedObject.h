//
//  DeletedObject.h
//  MacBox
//
//  Created by Strongbox on 14/05/2020.
//  Copyright © 2020 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "BaseXmlDomainObjectHandler.h"

NS_ASSUME_NONNULL_BEGIN

@interface DeletedObject : BaseXmlDomainObjectHandler

// <DeletedObject>
//     <UUID>OjDGBkygSXyeOh33r/aDJQ==</UUID>
//     <DeletionTime>2018-10-17T14:06:27Z</DeletionTime>
// </DeletedObject>

- (instancetype)initWithContext:(XmlProcessingContext*)context;

@property NSUUID* uuid;
@property NSDate* deletionTime;

@end

NS_ASSUME_NONNULL_END
