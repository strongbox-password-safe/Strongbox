//
//  KdbSerializationData.m
//  Strongbox
//
//  Created by Mark on 08/11/2018.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import "KdbSerializationData.h"

@implementation KdbSerializationData

- (instancetype)init
{
    self = [super init];
    if (self) {
        self.groups = [NSMutableArray array];
        self.entries = [NSMutableArray array];
        self.metaEntries = [NSMutableArray array];
    }
    
    return self;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"Groups = %@, Entries = %@, meta=%@", self.groups, self.entries, self.metaEntries];
}

@end
