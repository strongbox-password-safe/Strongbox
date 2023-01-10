//
//  PleaseConnectHardwareKey.h
//  MacBox
//
//  Created by Strongbox on 05/11/2021.
//  Copyright © 2021 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <Cocoa/Cocoa.h>
#import "MacHardwareKeyManager.h"

NS_ASSUME_NONNULL_BEGIN

@interface PleaseConnectHardwareKey : NSWindowController

+ (void)show:(MacHardwareKeyManagerOnDemandUIProviderBlock)parentHint completion:(void (^)(BOOL cancelled))completion;
+ (void)hide;

@end

NS_ASSUME_NONNULL_END
