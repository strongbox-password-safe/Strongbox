//
//  GenericTextDateElementHandler.m
//  Strongbox
//
//  Created by Mark on 20/10/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
//

#import "GenericTextDateElementHandler.h"
#import "Utils.h"

// 2018-10-17T19:28:42Z


const static NSISO8601DateFormatOptions kFormatOptions =   NSISO8601DateFormatWithInternetDateTime |
                                                    NSISO8601DateFormatWithDashSeparatorInDate |
                                                    NSISO8601DateFormatWithColonSeparatorInTime |
                                                    NSISO8601DateFormatWithTimeZone;

static const NSISO8601DateFormatter *formatter;

static NSDate* dotNetBaseEpochDate;

@interface GenericTextDateElementHandler ()

@end

@implementation GenericTextDateElementHandler

+ (void) initialize {
    if (self == [GenericTextDateElementHandler class]) {
        formatter = [[NSISO8601DateFormatter alloc] init];
        formatter.formatOptions = kFormatOptions;
        formatter.timeZone = [NSTimeZone timeZoneWithName:@"UTC"];
        dotNetBaseEpochDate = [formatter dateFromString:@"0001-01-01T00:00:00Z"];
    }
}

- (instancetype)initWithXmlElementName:(NSString *)xmlElementName context:(XmlProcessingContext *)context {
    if (self = [super initWithXmlElementName:xmlElementName context:context]) {
        self.date = [NSDate date];
    }
    
    return self;
}

- (void)onCompleted {
    if(self.context.v4Format) {
        NSString* text = [self getXmlText];
        NSData* dateData = [[NSData alloc] initWithBase64EncodedString:text options:NSDataBase64DecodingIgnoreUnknownCharacters];
        
        if(dateData.length != 8) {
            NSLog(@"DateData != 8!!");
            return;
        }
        
        uint64_t c = littleEndian8BytesToUInt64((uint8_t*)dateData.bytes);
        self.date = [NSDate dateWithTimeInterval:c sinceDate:dotNetBaseEpochDate];
    }
    else {
        self.date = [formatter dateFromString:[self getXmlText]];
    }
}

- (XmlTree *)generateXmlTree {
    XmlTree* ret = [[XmlTree alloc] initWithXmlElementName:self.nonCustomisedXmlTree.node.xmlElementName];
    
    ret.node = self.nonCustomisedXmlTree.node;
    
    if(self.context.v4Format) {
        NSTimeInterval interval = [self.date timeIntervalSinceDate:dotNetBaseEpochDate];
        NSData* dateData = Uint64ToLittleEndianData(interval);
        ret.node.xmlText = [dateData base64EncodedStringWithOptions:kNilOptions];
    }
    else {
        ret.node.xmlText = [formatter stringFromDate:self.date];
    }
    
    [ret.children addObjectsFromArray:self.nonCustomisedXmlTree.children];
    
    return ret;
}

- (NSString *)description {
    return [self.date description];
}

@end
