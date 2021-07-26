//
//  StringValue.m
//  Strongbox
//
//  Created by Mark on 27/03/2019.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import "StringValue.h"

@implementation StringValue

+ (instancetype)valueWithString:(NSString *)string {
    return [StringValue valueWithString:string protected:NO];
}

+ (instancetype)valueWithString:(NSString *)string protected:(BOOL)protected {
    StringValue* ret = [[StringValue alloc] init];
    
    ret.value = string;
    ret.protected = protected;
    
    return ret;
}

- (BOOL)isEqual:(id)object {
    if (object == nil) {
        return NO;
    }
    
    if (self == object) {
        return YES;
    }
    
    if (![object isKindOfClass:[StringValue class]]) {
        return NO;
    }
    
    StringValue* other = (StringValue*)object;
    if([self.value compare:other.value] != NSOrderedSame) {
        return NO;
    }
    if(self.protected != other.protected) {
        return NO;
    }
    
    return YES;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"%@%@", self.value, self.protected ? @" <Protected=True>" : @""];
}

@end
