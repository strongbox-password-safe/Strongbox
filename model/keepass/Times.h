//
//  Times.h
//  Strongbox
//
//  Created by Mark on 17/10/2018.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "BaseXmlDomainObjectHandler.h"

NS_ASSUME_NONNULL_BEGIN

@interface Times : BaseXmlDomainObjectHandler

// <Times>









- (instancetype)initWithContext:(XmlProcessingContext*)context;

@property (nullable) NSDate* lastModificationTime;
@property (nullable) NSDate* creationTime;
@property (nullable) NSDate* lastAccessTime;
@property (nullable) NSDate* expiryTime;
@property BOOL expires;
@property (nullable) NSNumber* usageCount;
@property (nullable) NSDate* locationChangedTime;

@end

NS_ASSUME_NONNULL_END
