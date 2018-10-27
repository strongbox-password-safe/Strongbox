//
//  XmlItem.m
//  Strongbox
//
//  Created by Mark on 18/10/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
//

#import "XmlItem.h"

@implementation XmlItem

- (instancetype)initWithXmlElementName:(NSString*)xmlElementName {
    if(self = [super init]) {
        self.xmlElementName = xmlElementName;
        self.xmlText = @"";
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

- (NSString *)description {
    return [[NSString stringWithFormat:@"[%@]-[%@]-[%@]", self.xmlElementName, self.xmlText, self.xmlAttributes]
            stringByReplacingOccurrencesOfString:@"\n" withString:@"\\n"];
}
@end
