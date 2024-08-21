//
//  SafesViewController.h
//  StrongBox
//
//  Created by Mark McGuill on 03/06/2014.
//  Copyright (c) 2014 Mark McGuill. All rights reserved.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface SafesViewController : UITableViewController

- (void)enqueueImport:(NSURL *)url canOpenInPlace:(BOOL)canOpenInPlace;
- (void)onAppLockScreenWillBeDismissed:(void (^ __nullable)(void))completion;
- (void)onAppLockScreenWasDismissed:(BOOL)userJustCompletedBiometricAuthentication;
- (void)performActionForShortcutItem:(UIApplicationShortcutItem *)shortcutItem;
- (void)handleOtpAuthUrl:(NSURL*)url;



@end

NS_ASSUME_NONNULL_END
