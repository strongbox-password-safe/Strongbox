//
//  NSDictionary+Extensions.m
//  Strongbox
//
//  Created by Mark on 08/04/2019.
//  Copyright © 2019 Mark McGuill. All rights reserved.
//

#import "NSDictionary+Extensions.h"

@implementation NSDictionary (Extensions)

- (id)objectForCaseInsensitiveKey:(NSString *)key {
    NSArray *allKeys = [self allKeys];
    for (NSString *str in allKeys) {
        if ([key caseInsensitiveCompare:str] == NSOrderedSame) {
            return [self objectForKey:str];
        }
    }
    return nil;
}

@end
