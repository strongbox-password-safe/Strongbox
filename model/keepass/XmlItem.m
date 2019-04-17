//
//  XmlItem.m
//  Strongbox
//
//  Created by Mark on 18/10/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
//

#import "XmlItem.h"

@interface XmlItem ()

@property NSMutableString* mutableText; // PERF: Quite an improvement using this as the backing. Due to the huge number of append calls from XML Parser

@end

@implementation XmlItem

- (instancetype)initWithXmlElementName:(NSString*)xmlElementName {
    if(self = [super init]) {
        self.xmlElementName = xmlElementName;
        self.mutableText = [NSMutableString stringWithString:@""];
        self.xmlAttributes = [NSMutableDictionary dictionary];
    }
    
    return self;
}

- (BOOL)isXmlEquivalent:(XmlItem*)other {
    BOOL ret = [self.xmlElementName isEqualToString:other.xmlElementName] &&
            ((self.xmlText == nil && other.xmlText == nil) || [self.xmlText isEqualToString:other.xmlText]) &&
            [self.xmlAttributes isEqualToDictionary:other.xmlAttributes];

    if(!ret) {
        NSLog(@"[%@] != [%@]", self, other);
    }
    
    return ret;
}

- (NSString *)xmlText {
    return self.mutableText;
}

- (void)setXmlText:(NSString *)xmlText {
    [self.mutableText setString:(xmlText == nil ? @"" : xmlText)];
}

- (void)appendXmlText:(NSString *)xmlText {
    if(xmlText.length) {
        [self.mutableText appendString:xmlText];
    }
}

- (NSString *)description {
    return [[NSString stringWithFormat:@"[%@]-[%@]-[%@]", self.xmlElementName, self.xmlText, self.xmlAttributes]
            stringByReplacingOccurrencesOfString:@"\n" withString:@"\\n"];
}

@end
