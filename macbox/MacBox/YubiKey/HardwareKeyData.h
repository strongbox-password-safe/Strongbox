//
//  YubiKeyData.h
//  MacBox
//
//  Created by Mark on 24/02/2020.
//  Copyright © 2020 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, HardwareKeySlotCrStatus) {
    kHardwareKeySlotCrStatusUnknown,
    kHardwareKeySlotCrStatusNotSupported,
    kHardwareKeySlotCrStatusSupportedBlocking,
    kHardwareKeySlotCrStatusSupportedNonBlocking,
};

@interface HardwareKeyData : NSObject

@property NSString* serial;
@property HardwareKeySlotCrStatus slot1CrStatus;
@property HardwareKeySlotCrStatus slot2CrStatus;

@property (readonly) BOOL slot1CrEnabled;
@property (readonly) BOOL slot2CrEnabled;


@end

NS_ASSUME_NONNULL_END
