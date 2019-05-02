//
//  CustomFieldViewModel.m
//  test-new-ui
//
//  Created by Mark on 23/04/2019.
//  Copyright © 2019 Mark McGuill. All rights reserved.
//

#import "CustomFieldViewModel.h"

@implementation CustomFieldViewModel

+ (instancetype)customFieldWithKey:(NSString*)key value:(NSString*)value protected:(BOOL)protected {
    CustomFieldViewModel* ret = [[CustomFieldViewModel alloc] init];
    
    ret.key = key;
    ret.value = value;
    ret.protected = protected;
    ret.concealedInUI = protected;
    
    return ret;
}

- (BOOL)isDifferentFrom:(CustomFieldViewModel *)other {
    return !([self.key isEqualToString:other.key] && [self.value isEqualToString:other.value] && self.protected == other.protected);
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"%@ => %@ %@", self.key, self.value, self.protected ? @"[Protected]" : @""];
}

@end
