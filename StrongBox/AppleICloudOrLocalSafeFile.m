//
//  AppleICloudOrLocalSafeFile.m
//  Strongbox
//
//  Created by Mark on 24/09/2017.
//  Copyright © 2017 Mark McGuill. All rights reserved.
//

#import "AppleICloudOrLocalSafeFile.h"

@implementation AppleICloudOrLocalSafeFile

- (instancetype)initWithDisplayName:(NSString*)displayName fileUrl:(NSURL*)fileUrl hasUnresolvedConflicts:(BOOL)hasUnresolvedConflicts {
    if(self = [super init]) {
        self.displayName = displayName;
        self.fileUrl = fileUrl;
        self.hasUnresolvedConflicts = hasUnresolvedConflicts;
    }
    
    return self;
}

-(NSString *)description {
    return [NSString stringWithFormat:@"%@-%@", self.displayName, [self.fileUrl lastPathComponent]];
}

@end
