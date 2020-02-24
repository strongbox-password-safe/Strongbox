//
//  YubiKeyHardwareConfiguration.m
//  Strongbox
//
//  Created by Mark on 07/02/2020.
//  Copyright © 2020 Mark McGuill. All rights reserved.
//

#import "YubiKeyHardwareConfiguration.h"

@implementation YubiKeyHardwareConfiguration

+ (instancetype)defaults {
    YubiKeyHardwareConfiguration* ret = [[YubiKeyHardwareConfiguration alloc] init];
    
    ret.mode = kNoYubiKey;
    ret.slot = kSlot1;
    
    return ret;
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    if((self = [self init])) {
        self.mode = [coder decodeIntegerForKey:@"mode"];
        self.slot = [coder decodeIntegerForKey:@"slot"];
    }
    
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder {
    [coder encodeInteger:self.mode forKey:@"mode"];
    [coder encodeInteger:self.slot forKey:@"slot"];
}

- (instancetype)clone {
    YubiKeyHardwareConfiguration* ret = [[YubiKeyHardwareConfiguration alloc] init];
    
    ret.mode = self.mode;
    ret.slot = self.slot;
    
    return ret;
}

- (BOOL)isEqual:(id)other {
    if (other == self) {
        return YES;
    }
    else if (![super isEqual:other]) {
        return NO;
    }

    if (![other isKindOfClass:[YubiKeyHardwareConfiguration class]]) {
        return NO;
    }

    YubiKeyHardwareConfiguration* oth = (YubiKeyHardwareConfiguration*)other;
    return self.mode == oth.mode && (self.mode == kNoYubiKey || self.slot == oth.slot);
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"[mode = %ld, slot = %ld]", (long)self.mode, (long)self.slot];
}

@end
