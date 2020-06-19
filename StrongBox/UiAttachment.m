//
//  UiAttachment.m
//  Strongbox
//
//  Created by Mark on 17/11/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
//

#import "UiAttachment.h"

@implementation UiAttachment

+ (instancetype)attachmentWithFilename:(NSString *)filename dbAttachment:(DatabaseAttachment *)dbAttachment {
    return [[UiAttachment alloc] initWithFilename:filename dbAttachment:dbAttachment];
}

- (instancetype)initWithFilename:(NSString *)filename dbAttachment:(DatabaseAttachment *)dbAttachment {
    self = [super init];
    if (self) {
        self.filename = filename;
        self.dbAttachment = dbAttachment;
    }
    return self;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"filename = %@, dbAttachment = [%@]", self.filename, self.dbAttachment];
}

@end
