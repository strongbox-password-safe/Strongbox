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

- (BOOL)appendStreamedText:(NSString*)text;

@property (readonly) BOOL handlesStreamingText;
@property (readonly) NSString* originalElementName;
@property (readonly) NSString* originalText;
@property (readonly) NSDictionary<NSString*, NSString*> *originalAttributes;
@property (readonly, nullable) NSArray<id<XmlParsingDomainObject>>* unmanagedChildren;

- (void)onCompleted;

- (nullable id<XmlParsingDomainObject>)getChildHandler:(NSString*)xmlElementName;

- (BOOL)addKnownChildObject:(id<XmlParsingDomainObject>)completedObject withXmlElementName:(NSString*)withXmlElementName; 

- (void)addUnknownChildObject:(id<XmlParsingDomainObject>)xmlItem;



- (BOOL)writeXml:(id<IXmlSerializer>)serializer;

@end

NS_ASSUME_NONNULL_END
