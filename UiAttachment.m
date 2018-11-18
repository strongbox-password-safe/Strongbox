//
//  UiAttachment.m
//  Strongbox
//
//  Created by Mark on 17/11/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
//

#import "UiAttachment.h"

@implementation UiAttachment

- (instancetype)initWithFilename:(NSString *)filename data:(NSData *)data {
    self = [super init];
    if (self) {
        self.filename = filename;
        self.data = data;
    }
    return self;
}

@end
