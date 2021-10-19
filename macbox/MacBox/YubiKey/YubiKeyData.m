//
//  YubiKeyData.m
//  MacBox
//
//  Created by Mark on 24/02/2020.
//  Copyright © 2020 Mark McGuill. All rights reserved.
//

#import "YubiKeyData.h"

@implementation YubiKeyData

- (NSString*)getStatusString:(YubiKeySlotCrStatus)status {
    if (status == YubiKeySlotCrStatusUnknown) {
        return @"Unknown";
    }
    else if (status == YubiKeySlotCrStatusNotSupported) {
        return @"Not Supported";
    }
    else if (status == YubiKeySlotCrStatusSupportedBlocking) {
        return @"Supported (Blocking)";
    }
    else if (status == YubiKeySlotCrStatusSupportedNonBlocking) {
        return @"Supported (Non Blocking)";
    }
    else {
        return @"ERROR!";
    }
}

- (NSString *)description {
    return [NSString stringWithFormat:@"Serial: %@ [Slot 1: %@ - Slot 2: %@]",
            self.serial,
            [self getStatusString:self.slot1CrStatus],
            [self getStatusString:self.slot2CrStatus]];
}

@end
