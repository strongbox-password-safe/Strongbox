//
//  WordList.m
//  Strongbox
//
//  Created by Strongbox on 14/05/2020.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import "WordList.h"

@implementation WordList

+ (instancetype)named:(NSString *)name withKey:(NSString *)withKey withCategory:(WordListCategory)withCategory {
    return [[WordList alloc] initWithName:name withKey:withKey withCategory:withCategory];
}

- (instancetype)initWithName:(NSString *)name withKey:(NSString *)withKey withCategory:(WordListCategory)withCategory {
    self = [super init];
    if (self) {
        _name = name;
        _key = withKey;
        _category = withCategory;
    }
    return self;
}

@end

