//
//  Handler.h
//  Strongbox
//
//  Created by Mark on 17/10/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "XmlTree.h"

NS_ASSUME_NONNULL_BEGIN

@protocol XmlParsingDomainObject <NSObject>

- (void)setXmlInfo:(NSString*)elementName attributes:(NSDictionary*)attributes;
- (void)setXmlInfo:(nonnull NSString *)elementName
        attributes:(nonnull NSDictionary *)attributes
              text:(nonnull NSString *)text;

- (NSString*)getXmlText;
- (void)appendXmlText:(NSString*)text;
- (void)setXmlAttribute:(NSString*)key value:(NSString*)value;
- (void)setXmlText:(NSString*)text;
- (void)onCompleted;

- (nullable id<XmlParsingDomainObject>)getChildHandler:(NSString*)xmlElementName;
- (BOOL)addKnownChildObject:(NSObject*)completedObject withXmlElementName:(NSString*)withXmlElementName; // return YES if you handle this element/object
- (void)addUnknownChildObject:(XmlTree*)xmlItem;

@property (nonatomic) XmlTree* nonCustomisedXmlTree;

// Generated from newly set values/modifications...

- (XmlTree*)generateXmlTree;

@end

NS_ASSUME_NONNULL_END
