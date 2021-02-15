//
//  ItemMetadataEntry.m
//  Strongbox-iOS
//
//  Created by Mark on 27/04/2019.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import "ItemMetadataEntry.h"

@implementation ItemMetadataEntry

+ (instancetype)entryWithKey:(NSString *)key value:(NSString *)value copyable:(BOOL)copyable {
    return [[ItemMetadataEntry alloc] initWithKey:key value:value copyable:copyable];
}

- (instancetype)initWithKey:(NSString *)key value:(NSString *)value copyable:(BOOL)copyable {
    self = [super init];
    if (self) {
        self.key = key;
        self.value = value;
        self.copyable = copyable;
    }
    return self;
}
    
@end
