//
//  RootHandler.h
//  Strongbox
//
//  Created by Mark on 17/10/2018.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "XmlParsingDomainObject.h"
#import "XmlProcessingContext.h"

NS_ASSUME_NONNULL_BEGIN

@interface BaseXmlDomainObjectHandler : NSObject<XmlParsingDomainObject>

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithXmlElementName:(NSString*)xmlElementName context:(XmlProcessingContext*)context NS_DESIGNATED_INITIALIZER;

@property (nonatomic) XmlProcessingContext* context;

- (BOOL)writeUnmanagedChildren:(id<IXmlSerializer>)serializer;

@end

NS_ASSUME_NONNULL_END
