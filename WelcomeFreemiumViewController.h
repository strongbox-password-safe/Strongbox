//
//  WelcomeFreemiumViewController.h
//  Strongbox
//
//  Created by Mark on 03/04/2020.
//  Copyright © 2020 Mark McGuill. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "SafeMetaData.h"

NS_ASSUME_NONNULL_BEGIN

@interface WelcomeFreemiumViewController : UIViewController

@property (nonatomic, copy) void (^onDone)(BOOL purchasedOrRestoredFreeTrial);

@end

NS_ASSUME_NONNULL_END
