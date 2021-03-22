//
//  PrivacyViewController.h
//  Strongbox-iOS
//
//  Created by Mark on 14/05/2019.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface AppLockViewController : UIViewController

@property (nonatomic, copy) void (^onUnlockDone)(BOOL userJustCompletedBiometricAuthentication);

@end

NS_ASSUME_NONNULL_END
