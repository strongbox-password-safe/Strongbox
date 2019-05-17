//
//  PrivacyViewController.h
//  Strongbox-iOS
//
//  Created by Mark on 14/05/2019.
//  Copyright © 2019 Mark McGuill. All rights reserved.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface PrivacyViewController : UIViewController

@property (nonatomic, copy) void (^onUnlockDone)(void);
@property BOOL startupLockMode;

- (void)onAppBecameActive;

@end

NS_ASSUME_NONNULL_END
