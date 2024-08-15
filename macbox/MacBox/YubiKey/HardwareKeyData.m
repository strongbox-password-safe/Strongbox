//
//  YubiKeyData.m
//  MacBox
//
//  Created by Mark on 24/02/2020.
//  Copyright © 2020 Mark McGuill. All rights reserved.
//

#import "HardwareKeyData.h"

@implementation HardwareKeyData

- (NSString*)getStatusString:(HardwareKeySlotCrStatus)status {
    if (status == kHardwareKeySlotCrStatusUnknown) {
        return @"Unknown";
    }
    else if (status == kHardwareKeySlotCrStatusNotSupported) {
        return @"Not Supported";
    }
    else if (status == kHardwareKeySlotCrStatusSupportedBlocking) {
        return @"Supported (Blocking)";
    }
    else if (status == kHardwareKeySlotCrStatusSupportedNonBlocking) {
        return @"Supported (Non Blocking)";
    }
    else {
        return @"ERROR!";
    }
}

- (BOOL)yubiKeyCrIsSupported:(HardwareKeySlotCrStatus)status {
    return status == kHardwareKeySlotCrStatusSupportedBlocking || status == kHardwareKeySlotCrStatusSupportedNonBlocking;
}

- (BOOL)slot1CrEnabled {
    return [self yubiKeyCrIsSupported:self.slot1CrStatus];
}

- (BOOL)slot2CrEnabled {
    return [self yubiKeyCrIsSupported:self.slot2CrStatus];
}

- (NSString *)description {
    return [NSString stringWithFormat:@"Serial: %@ [Slot 1: %@ - Slot 2: %@]",
            self.serial,
            [self getStatusString:self.slot1CrStatus],
            [self getStatusString:self.slot2CrStatus]];
}

@end
