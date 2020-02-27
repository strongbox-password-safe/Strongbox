//
//  YubiKeyData.h
//  MacBox
//
//  Created by Mark on 24/02/2020.
//  Copyright © 2020 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, YubiKeySlotCrStatus) {
    YubiKeySlotCrStatusUnknown,
    YubiKeySlotCrStatusNotSupported,
    YubiKeySlotCrStatusSupportedBlocking,
    YubiKeySlotCrStatusSupportedNonBlocking,
};

@interface YubiKeyData : NSObject

@property NSString* serial;
@property YubiKeySlotCrStatus slot1CrStatus;
@property YubiKeySlotCrStatus slot2CrStatus;

@end

NS_ASSUME_NONNULL_END
