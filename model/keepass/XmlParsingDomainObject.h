//
//  Handler.h
//  Strongbox
//
//  Created by Mark on 17/10/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "IXmlSerializer.h"

NS_ASSUME_NONNULL_BEGIN

@protocol XmlParsingDomainObject <NSObject>

- (void)setXmlInfo:(NSString*)elementName attributes:(NSDictionary*)attributes;
- (void)setXmlText:(NSString*)text;

@property (readonly) NSString* originalElementName;
@property (readonly) NSString* originalText;
@property (readonly) NSDictionary* originalAttributes;
@property (readonly, nullable) NSArray<id<XmlParsingDomainObject>>* unmanagedChildren;

- (void)onCompleted;

- (nullable id<XmlParsingDomainObject>)getChildHandler:(NSString*)xmlElementName;

- (BOOL)addKnownChildObject:(id<XmlParsingDomainObject>)completedObject withXmlElementName:(NSString*)withXmlElementName; // return YES

- (void)addUnknownChildObject:(id<XmlParsingDomainObject>)xmlItem;

// Performance Critical Functions

- (BOOL)writeXml:(id<IXmlSerializer>)serializer;

@end

NS_ASSUME_NONNULL_END
