//
//  SimpleXmlValueExtractor.m
//  Strongbox
//
//  Created by Mark on 05/09/2019.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import "SimpleXmlValueExtractor.h"
#import "KeePassConstants.h"
#import "Utils.h"
#import "NSString+Extensions.h"
#import "SBLog.h"

// 2018-10-17T19:28:42Z


const static NSISO8601DateFormatOptions kFormatOptions =   NSISO8601DateFormatWithInternetDateTime |
NSISO8601DateFormatWithDashSeparatorInDate |
NSISO8601DateFormatWithColonSeparatorInTime |
NSISO8601DateFormatWithTimeZone;

static const NSISO8601DateFormatter *formatter;

static NSDate* dotNetBaseEpochDate;

@implementation SimpleXmlValueExtractor

+ (void) initialize {
    if (self == [SimpleXmlValueExtractor class]) {
        
        
        
        
        
        
        
        
        
        
        
        formatter = [[NSISO8601DateFormatter alloc] init];
        formatter.formatOptions = kFormatOptions;
        formatter.timeZone = [NSTimeZone timeZoneWithName:@"UTC"];
        dotNetBaseEpochDate = [formatter dateFromString:@"0001-01-03T00:00:00Z"];
    }
}



+ (NSString *)getStringFromText:(id<XmlParsingDomainObject>)xmlObject {
    return xmlObject.originalText;
}

+ (StringValue *)getStringValueFromText:(id<XmlParsingDomainObject>)xmlObject {
    NSString* text = xmlObject.originalText;
    
    BOOL protected = NO;
    
    if (xmlObject.originalAttributes && (xmlObject.originalAttributes[kAttributeProtected])) {
        NSString* protectedString = xmlObject.originalAttributes[kAttributeProtected];
        protected = protectedString.isKeePassXmlBooleanStringTrue;
    }
        
    return [StringValue valueWithString:text protected:protected];
}

+ (NSInteger)integerFromAttributeNamed:(NSString*)attribute xmlObject:(id<XmlParsingDomainObject>)xmlObject {
    NSString* ref = xmlObject.originalAttributes ? xmlObject.originalAttributes[attribute] : @"0";
    return ref ? ref.integerValue : 0;
}



+ (NSDate *)getDate:(id<XmlParsingDomainObject>)xmlObject v4Format:(BOOL)v4Format {
    if(v4Format) {
        NSString* text = xmlObject.originalText;
        NSData* dateData = [[NSData alloc] initWithBase64EncodedString:text options:NSDataBase64DecodingIgnoreUnknownCharacters];
        
        if(dateData.length != 8) {
            slog(@"🔴 DateData != 8!!");
            return nil;
        }
        
        uint64_t c = littleEndian8BytesToUInt64((uint8_t*)dateData.bytes);
        return [NSDate dateWithTimeInterval:c sinceDate:dotNetBaseEpochDate];
    }
    else {
        return [formatter dateFromString:xmlObject.originalText];
    }
}

+ (NSString *)getV4String:(NSDate *)date {
    NSTimeInterval interval = [date timeIntervalSinceDate:dotNetBaseEpochDate];
    NSData* dateData = Uint64ToLittleEndianData(interval);
    return [dateData base64EncodedStringWithOptions:kNilOptions];
}

+ (NSString *)getV3String:(NSDate *)date {
    return [formatter stringFromDate:date];
}



+ (NSUUID *)getUuid:(id<XmlParsingDomainObject>)xmlObject {
    NSData *uuidData = xmlObject.originalText ? [[NSData alloc] initWithBase64EncodedString:xmlObject.originalText
                                                                                    options:NSDataBase64DecodingIgnoreUnknownCharacters] : nil;
    
    if(uuidData && uuidData.length == sizeof(uuid_t)) {
        return [[NSUUID alloc] initWithUUIDBytes:uuidData.bytes];
    }
    else {
        return nil;
    }
}



+ (NSNumber*)getNumber:(id<XmlParsingDomainObject>)xmlObject {
    return xmlObject.originalText.length ? @(xmlObject.originalText.integerValue) : nil;
}



+ (NSNumber*)getOptionalBool:(id<XmlParsingDomainObject>)xmlObject {
    if (xmlObject.originalText.length) {
        if (xmlObject.originalText.isKeePassXmlBooleanStringTrue) {
            return @YES;
        }
        
        if (xmlObject.originalText.isKeePassXmlBooleanStringFalse) {
            return @NO;
        }
        
        if (xmlObject.originalText.isKeePassXmlBooleanStringNull) {
            return nil;
        }
    }
    
    return nil;
}

+ (BOOL)getBool:(id<XmlParsingDomainObject>)xmlObject {
    return [self getBool:xmlObject defaultValue:NO];
}

+ (BOOL)getBool:(id<XmlParsingDomainObject>)xmlObject defaultValue:(BOOL)defaultValue {
    if ( !xmlObject.originalText.length ) {
        return defaultValue;
    }
    else {
        return xmlObject.originalText.isKeePassXmlBooleanStringTrue;
    }
}

@end
