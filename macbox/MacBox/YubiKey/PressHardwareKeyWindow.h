//
//  PressYubiKeyWindow.h
//  Strongbox
//
//  Created by Mark on 26/02/2020.
//  Copyright © 2020 Mark McGuill. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "MacHardwareKeyManager.h"

NS_ASSUME_NONNULL_BEGIN

@interface PressHardwareKeyWindow : NSWindowController

+ (void)show:(MacHardwareKeyManagerOnDemandUIProviderBlock)parentHint;
+ (void)hide;

@end

NS_ASSUME_NONNULL_END
