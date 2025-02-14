//
//  AboutViewController.h
//  Strongbox-iOS
//
//  Created by Mark on 30/05/2019.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface AboutViewController : UIViewController

@property (nonatomic, copy) void (^onDone)(void);

@end

NS_ASSUME_NONNULL_END
