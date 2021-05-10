//
//  SimpleXmlValueExtractor.h
//  Strongbox
//
//  Created by Mark on 05/09/2019.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "StringValue.h"
#import "XmlParsingDomainObject.h"

NS_ASSUME_NONNULL_BEGIN

@interface SimpleXmlValueExtractor : NSObject



+ (StringValue*_Nullable)getStringValueFromText:(id<XmlParsingDomainObject>)xmlObject;
+ (NSString*_Nullable)getStringFromText:(id<XmlParsingDomainObject>)xmlObject;
+ (NSInteger)integerFromAttributeNamed:(NSString*)attribute xmlObject:(id<XmlParsingDomainObject>)xmlObject;



+ (NSDate *_Nullable)getDate:(id<XmlParsingDomainObject>)xmlObject v4Format:(BOOL)v4Format;

+ (NSString *)getV4String:(NSDate *)date;
+ (NSString *)getV3String:(NSDate *)date;



+ (NSUUID*_Nullable)getUuid:(id<XmlParsingDomainObject>)xmlObject;



+ (NSNumber*_Nullable)getNumber:(id<XmlParsingDomainObject>)xmlObject;



+ (NSNumber*_Nullable)getOptionalBool:(id<XmlParsingDomainObject>)xmlObject;
+ (BOOL)getBool:(id<XmlParsingDomainObject>)xmlObject;
+ (BOOL)getBool:(id<XmlParsingDomainObject>)xmlObject defaultValue:(BOOL)defaultValue;

@end

NS_ASSUME_NONNULL_END
