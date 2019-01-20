//
//  LockViewController.h
//  Strongbox
//
//  Created by Mark on 17/01/2019.
//  Copyright © 2019 Mark McGuill. All rights reserved.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface LockViewController : UIViewController

@property (weak, nonatomic) IBOutlet UIImageView *logo;

@property (nonatomic, copy) void (^onUnlockSuccessful)(void);
@property (weak, nonatomic) IBOutlet UIButton *buttonTap;

@end

NS_ASSUME_NONNULL_END
