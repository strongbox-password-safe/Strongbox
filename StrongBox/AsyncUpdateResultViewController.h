//
//  AsyncUpdateResultViewController.h
//  Strongbox
//
//  Created by Strongbox on 29/03/2021.
//  Copyright © 2021 Mark McGuill. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "AsyncUpdateResult.h"

NS_ASSUME_NONNULL_BEGIN

@interface AsyncUpdateResultViewController : UIViewController

@property AsyncUpdateResult* result;
@property (nonatomic, copy) void (^onRetryClicked)(void);

@end

NS_ASSUME_NONNULL_END
