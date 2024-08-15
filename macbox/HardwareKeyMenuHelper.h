//
//  YubiKeyMenuHelper.h
//  MacBox
//
//  Created by Strongbox on 11/08/2024.
//  Copyright © 2024 Mark McGuill. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "YubiKeyConfiguration.h"

NS_ASSUME_NONNULL_BEGIN

@interface HardwareKeyMenuHelper : NSObject

- (instancetype)initWithViewController:(NSViewController*)viewController
                          yubiKeyPopup:(NSPopUpButton*)yubiKeyPopup
                  currentConfiguration:(YubiKeyConfiguration*_Nullable)currentConfiguration
                            verifyMode:(BOOL)verifyMode;

- (void)scanForConnectedAndRefresh;

@property (nullable) YubiKeyConfiguration* selectedConfiguration;


@property (nullable) void (^showViewControllerOverride)(NSViewController*);
@property (nullable) void (^dismissViewControllerOverride)(void);
@property (nullable, weak) NSWindow* alertWindowOverride;

@end

NS_ASSUME_NONNULL_END
