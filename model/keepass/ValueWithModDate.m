//
//  ValueWithModDate.m
//  Strongbox
//
//  Created by Strongbox on 28/04/2021.
//  Copyright © 2021 Mark McGuill. All rights reserved.
//

#import "ValueWithModDate.h"
#import "NSDate+Extensions.h"

@implementation ValueWithModDate

+ (instancetype)value:(NSString *)value modified:(NSDate *)modified {
    return [[ValueWithModDate alloc] initWithValue:value modified:modified];
}

- (instancetype)initWithValue:(NSString *)value modified:(NSDate *)modified {
    self = [super init];
    if (self) {
        _value = value;
        _modified = modified;
    }
    return self;
}

- (BOOL)isEqual:(id)object {
    if (object == nil) {
        return NO;
    }
    
    if (self == object) {
        return YES;
    }
    
    if (![object isKindOfClass:[ValueWithModDate class]]) {
        return NO;
    }
    
    ValueWithModDate* other = (ValueWithModDate*)object;
 
    BOOL valuesDifferent = ((self.value == nil && other.value != nil) || (self.value != nil && ![self.value isEqualToString:other.value]));
    BOOL modsDifferent = ((self.modified == nil && other.modified != nil) || (self.modified != nil && ![self.modified isEqual:other.modified]));

    if ( valuesDifferent || modsDifferent ) {
        return NO;
    }
    
    return YES;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"%@ (%@)", self.value, self.modified.friendlyDateStringVeryShort];
}
@end
