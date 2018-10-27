//
//  GenericTextDateElementHandler.m
//  Strongbox
//
//  Created by Mark on 20/10/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
//

#import "GenericTextDateElementHandler.h"

// 2018-10-17T19:28:42Z

const static NSISO8601DateFormatOptions kFormatOptions =   NSISO8601DateFormatWithInternetDateTime |
                                                    NSISO8601DateFormatWithDashSeparatorInDate |
                                                    NSISO8601DateFormatWithColonSeparatorInTime |
                                                    NSISO8601DateFormatWithTimeZone;

static const NSISO8601DateFormatter *formatter;

@interface GenericTextDateElementHandler ()

@end

@implementation GenericTextDateElementHandler

+ (void) initialize {
    if (self == [GenericTextDateElementHandler class]) {
        formatter = [[NSISO8601DateFormatter alloc] init];
        formatter.formatOptions = kFormatOptions;
        formatter.timeZone = [NSTimeZone timeZoneWithName:@"UTC"];
    }
}

- (instancetype)initWithXmlElementName:(NSString*)xmlElementName {
    if (self = [super initWithXmlElementName:xmlElementName]) {
        self.date = [NSDate date];
    }
    
    return self;
}

- (void)onCompleted {
    self.date = [formatter dateFromString:[self getXmlText]];
}

- (XmlTree *)generateXmlTree {
    XmlTree* ret = [[XmlTree alloc] initWithXmlElementName:self.nonCustomisedXmlTree.node.xmlElementName];
    
    ret.node = self.nonCustomisedXmlTree.node;
    ret.node.xmlText = [formatter stringFromDate:self.date];
    [ret.children addObjectsFromArray:self.nonCustomisedXmlTree.children];
    
    return ret;
}

- (NSString *)description {
    return [self.date description];
}

@end
