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
    ret.virtualKeyIdentifier = nil;
    
    return ret;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//

+ (instancetype)fromJsonSerializationDictionary:(NSDictionary *)jsonDictionary {
    YubiKeyHardwareConfiguration* ret = YubiKeyHardwareConfiguration.defaults;
    
    if (jsonDictionary[@"mode"] != nil ) ret.mode = ((NSNumber*)(jsonDictionary[@"mode"])).unsignedIntegerValue;
    if (jsonDictionary[@"slot"] != nil ) ret.slot = ((NSNumber*)(jsonDictionary[@"slot"])).unsignedIntegerValue;
    if (jsonDictionary[@"virtualKeyIdentifier"] != nil ) ret.virtualKeyIdentifier = jsonDictionary[@"virtualKeyIdentifier"];
    
    return ret;
}

- (NSDictionary *)getJsonSerializationDictionary {
    NSMutableDictionary *ret = [NSMutableDictionary dictionaryWithDictionary:@{
        @"mode" : @(self.mode),
        @"slot" : @(self.slot),
    }];

    if (self.virtualKeyIdentifier) {
        ret[@"virtualKeyIdentifier"] = self.virtualKeyIdentifier;
    }

    return ret;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Legacy Serialization - Remove eventually

- (instancetype)initWithCoder:(NSCoder *)coder {
    if((self = [self init])) {
        self.mode = [coder decodeIntegerForKey:@"mode"];
        self.slot = [coder decodeIntegerForKey:@"slot"];
        
        if ( [coder containsValueForKey:@"virtualKeyIdentifier"] ) {
            self.virtualKeyIdentifier = [coder decodeObjectForKey:@"virtualKeyIdentifier"];
        }
    }
    
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder {
    [coder encodeInteger:self.mode forKey:@"mode"];
    [coder encodeInteger:self.slot forKey:@"slot"];
    [coder encodeObject:self.virtualKeyIdentifier forKey:@"virtualKeyIdentifier"];
}

- (instancetype)clone {
    YubiKeyHardwareConfiguration* ret = [[YubiKeyHardwareConfiguration alloc] init];
    
    ret.mode = self.mode;
    ret.slot = self.slot;
    ret.virtualKeyIdentifier = self.virtualKeyIdentifier;
    
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
    
    if (self.mode != oth.mode) {
        return NO;
    }
    
    if (self.mode == kNoYubiKey) {
        return YES;
    }
    
    if (self.mode == kVirtual) {
        return self.virtualKeyIdentifier == oth.virtualKeyIdentifier;
    }
    
    return self.slot == oth.slot;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"[mode = %ld, slot = %ld]", (long)self.mode, (long)self.slot];
}

@end
