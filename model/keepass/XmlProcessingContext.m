//
//  XmlParsingContext.m
//  Strongbox
//
//  Created by Mark on 06/11/2018.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import "XmlProcessingContext.h"

@implementation XmlProcessingContext

- (instancetype)initWithV4Format:(BOOL)v4Format
{
    self = [super init];
    if (self) {
        self.v4Format = v4Format;
    }
    return self;
}

+ (instancetype)standardV3Context {
    return [[XmlProcessingContext alloc] initWithV4Format:NO];
}

+ (instancetype)standardV4Context {
    return [[XmlProcessingContext alloc] initWithV4Format:YES];
}

@end
