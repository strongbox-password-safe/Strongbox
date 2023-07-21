//
//  UpgradeViewController.h
//  Strongbox-iOS
//
//  Created by Mark on 11/03/2020.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface UpgradeViewController : UIViewController

+ (instancetype)fromStoryboard;

@property (nonatomic, copy, nullable) void (^onDone)(void);

@end

NS_ASSUME_NONNULL_END
