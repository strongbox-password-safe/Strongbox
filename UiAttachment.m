//
//  UiAttachment.m
//  Strongbox
//
//  Created by Mark on 17/11/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
//

#import "UiAttachment.h"

@implementation UiAttachment

+ (instancetype)attachmentWithFilename:(NSString *)filename data:(NSData *)data {
    return [[UiAttachment alloc] initWithFilename:filename data:data];
}

- (instancetype)initWithFilename:(NSString *)filename data:(NSData *)data {
    self = [super init];
    if (self) {
        self.filename = filename;
        self.data = data;
    }
    return self;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"filename = %@, size = [%lul]", self.filename, (unsigned long)self.data.length];
}

@end
