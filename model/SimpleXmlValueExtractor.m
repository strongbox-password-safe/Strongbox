//
//  SimpleXmlValueExtractor.m
//  Strongbox
//
//  Created by Mark on 05/09/2019.
//  Copyright © 2019 Mark McGuill. All rights reserved.
//

#import "SimpleXmlValueExtractor.h"
#import "KeePassConstants.h"

#import "Utils.h"

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
        // MMcG: Weirdly the way Microsoft and Apple calculate their intervals from the reference date
        // is different (off by exactly 2 days) - This led to an issue where dates were being displayed
        // as 2 days behind when edited in Windows (KeePass) and then displayed on Windows as being
        // 2 days in the future when edited with Strongbox. This also only happened for KDBX4 files
        // Bit of a cryptic one but for reference:
        //
        // https://github.com/mmcguill/Strongbox/issues/117
        //
        // We now use the below Midnight 3rd January 0001 as the base epoch for .Net Dates to keep in line
        // with KeePass on Windows (.NET)
        
        formatter = [[NSISO8601DateFormatter alloc] init];
        formatter.formatOptions = kFormatOptions;
        formatter.timeZone = [NSTimeZone timeZoneWithName:@"UTC"];
        dotNetBaseEpochDate = [formatter dateFromString:@"0001-01-03T00:00:00Z"];
    }
}

// Strings

+ (NSString *)getStringFromText:(id<XmlParsingDomainObject>)xmlObject {
    return xmlObject.originalText;
}

+ (StringValue *)getStringValueFromText:(id<XmlParsingDomainObject>)xmlObject {
    NSString* text = xmlObject.originalText;
    BOOL protected = xmlObject.originalAttributes &&
    (xmlObject.originalAttributes[kAttributeProtected] &&
     ([xmlObject.originalAttributes[kAttributeProtected] isEqualToString:kAttributeValueTrue]));

    return [StringValue valueWithString:text protected:protected];
}

+ (NSInteger)integerFromAttributeNamed:(NSString*)attribute xmlObject:(id<XmlParsingDomainObject>)xmlObject {
    NSString* ref = xmlObject.originalAttributes ? xmlObject.originalAttributes[attribute] : @"0";
    return ref ? ref.integerValue : 0;
}

// Dates

+ (NSDate *)getDate:(id<XmlParsingDomainObject>)xmlObject v4Format:(BOOL)v4Format {
    if(v4Format) {
        NSString* text = xmlObject.originalText;
        NSData* dateData = [[NSData alloc] initWithBase64EncodedString:text options:NSDataBase64DecodingIgnoreUnknownCharacters];
        
        if(dateData.length != 8) {
            NSLog(@"DateData != 8!!");
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

// UUID

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

// Numbers

+ (NSNumber*)getNumber:(id<XmlParsingDomainObject>)xmlObject {
    return xmlObject.originalText.length ? @(xmlObject.originalText.integerValue) : nil;
}

// Boolean

+ (BOOL)getBool:(id<XmlParsingDomainObject>)xmlObject {
    return (xmlObject.originalText.length && [xmlObject.originalText isEqualToString:@"True"]);
}

@end
