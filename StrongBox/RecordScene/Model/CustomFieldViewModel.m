//
//  CustomFieldViewModel.m
//  test-new-ui
//
//  Created by Mark on 23/04/2019.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import "CustomFieldViewModel.h"

@implementation CustomFieldViewModel

+ (instancetype)customFieldWithKey:(NSString*)key value:(NSString*)value protected:(BOOL)protected {
    return [[CustomFieldViewModel alloc] initWithKey:key value:value protected:protected];
}

- (instancetype)initWithKey:(NSString*)key value:(NSString*)value protected:(BOOL)protected
{
    self = [super init];
    if (self) {
        _key = key;
        _value = value;
        _protected = protected;
        
        self.concealedInUI = protected;
    }
    return self;
}

- (BOOL)isDifferentFrom:(CustomFieldViewModel *)other {
    return !([self.key compare:other.key] == NSOrderedSame &&
             [self.value compare:other.value] == NSOrderedSame && self.protected == other.protected);
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"%@ => %@ %@", self.key, self.value, self.protected ? @"[Protected]" : @""];
}

@end
