//
//  KdbEntry.m
//  Strongbox
//
//  Created by Mark on 08/11/2018.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import "KdbEntry.h"

@implementation KdbEntry

- (instancetype)init {
    self = [super init];
    if (self) {
        self.title = @"";
        self.url = @"";
        self.username = @"";
        self.password = @"";
        self.notes = @"";
        self.creation = [NSDate date];
        self.imageId = @(0);
    }
    return self;
}

- (BOOL)isMetaEntry {
    if(!self.binaryData) return NO;
    if(!self.notes) return NO;
    if(!self.binaryFileName) return NO;
    
    if(![self.binaryFileName isEqualToString:@"bin-stream"]) return NO;
    
    if(!self.title) return NO;
    if(![self.title isEqualToString:@"Meta-Info"]) return NO;
    
    if(!self.username) return NO;
    if(![self.username isEqualToString:@"SYSTEM"]) return NO;
    
    if(!self.url) return NO;
    if(![self.url isEqualToString:@"$"]) return NO;
    
    if(![self.imageId isEqual: @(0)]) return NO;
    
    return YES;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"%@-%@-%@-%@-%@- group=[%u] [%@] Meta=%d", self.title, self.username, self.password, self.url, self.notes, self.groupId, self.creation, self.isMetaEntry];
}

@end
