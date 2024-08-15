//
//  YubiKeyConfiguration.m
//  MacBox
//
//  Created by Mark on 25/02/2020.
//  Copyright © 2020 Mark McGuill. All rights reserved.
//

#import "YubiKeyConfiguration.h"

@implementation YubiKeyConfiguration

+ (instancetype)virtualKeyWithSerial:(NSString *)serial {
    return [[YubiKeyConfiguration alloc] initWithVirtual:YES serial:serial slot:0];
}

+ (instancetype)realKeyWithSerial:(NSString *)serial slot:(NSInteger)slot {
    return [[YubiKeyConfiguration alloc] initWithVirtual:NO serial:serial slot:slot];
}

- (instancetype)initWithVirtual:(BOOL)virtual serial:(NSString*)serial slot:(NSInteger)slot {
    self = [super init];
    
    if (self) {
        self.isVirtual = virtual;
        self.deviceSerial = serial;
        self.slot = slot;
    }
    
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    if (self) {
        self.deviceSerial = [coder decodeObjectForKey:@"deviceSerial"];
        self.slot = [coder decodeIntegerForKey:@"slot"];
        
        if ( [coder containsValueForKey:@"isVirtual"] ) {
            self.isVirtual = [coder decodeBoolForKey:@"isVirtual"];
        }
    }
    
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder {
    [coder encodeObject:self.deviceSerial forKey:@"deviceSerial"];
    [coder encodeInteger:self.slot forKey:@"slot"];
    [coder encodeBool:self.isVirtual forKey:@"isVirtual"];
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
    
    if ( self.isVirtual ) {
        return self.isVirtual == otherConfig.isVirtual && [self.deviceSerial isEqualToString:otherConfig.deviceSerial];
    }
    else {
        return self.isVirtual == otherConfig.isVirtual && [self.deviceSerial isEqualToString:otherConfig.deviceSerial] && self.slot == otherConfig.slot;
    }
}

- (NSString *)description {
    return [NSString stringWithFormat:@"[%@]Device Serial: - %@ (Slot %ld)", self.isVirtual ? @"V" : @"R", self.deviceSerial, (long)self.slot];
}

@end
