//
//  Times.h
//  Strongbox
//
//  Created by Mark on 17/10/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "BaseXmlDomainObjectHandler.h"

NS_ASSUME_NONNULL_BEGIN

@interface Times : BaseXmlDomainObjectHandler

// <Times>
//    <LastModificationTime>2018-10-17T19:28:42Z</LastModificationTime>
//    <CreationTime>2018-10-17T19:28:42Z</CreationTime>
//    <LastAccessTime>2018-10-17T19:28:42Z</LastAccessTime>
//    <ExpiryTime>4001-01-01T00:00:00Z</ExpiryTime>
//    <Expires>False</Expires>
//    <UsageCount>0</UsageCount>
//    <LocationChanged>2018-10-17T19:28:42Z</LocationChanged>
// </Times>

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
