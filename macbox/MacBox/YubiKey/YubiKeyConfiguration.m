//
//  YubiKeyConfiguration.m
//  MacBox
//
//  Created by Mark on 25/02/2020.
//  Copyright © 2020 Mark McGuill. All rights reserved.
//

#import "YubiKeyConfiguration.h"

@implementation YubiKeyConfiguration

- (instancetype)initWithCoder:(NSCoder *)coder {
    if (self) {
        self.deviceSerial = [coder decodeObjectForKey:@"deviceSerial"];
        self.slot = [coder decodeIntegerForKey:@"slot"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder {
    [coder encodeObject:self.deviceSerial forKey:@"deviceSerial"];
    [coder encodeInteger:self.slot forKey:@"slot"];
}

- (BOOL)isEqual:(id)other {
    if (other == nil) {
        return NO;
    }
    if (self == other) {
        return YES;
    }
    if ( ![other isKindOfClass:[YubiKeyConfiguration class]] ) {
        return NO;
    }
    
    YubiKeyConfiguration* otherConfig = (YubiKeyConfiguration*)other;
    return [self.deviceSerial isEqualToString:otherConfig.deviceSerial] && self.slot == otherConfig.slot;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"Device Serial: %@ (Slot %ld)", self.deviceSerial, (long)self.slot];
}

@end
