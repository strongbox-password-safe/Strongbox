//
//  Times.h
//  Strongbox
//
//  Created by Mark on 17/10/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "BaseXmlDomainObjectHandler.h"
#import "GenericTextDateElementHandler.h"

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

@property (nonatomic) GenericTextDateElementHandler* lastModificationTime;
@property (nonatomic) GenericTextDateElementHandler* creationTime;
@property (nonatomic) GenericTextDateElementHandler* lastAccessTime;

//@property (nonatomic) GenericTextElementHandler* expiryTime;        // TODO:
//@property (nonatomic) GenericTextElementHandler* locationChanged;   // TODO:
// expires          // TODO:
// usageCount       // TODO:


@end

NS_ASSUME_NONNULL_END
