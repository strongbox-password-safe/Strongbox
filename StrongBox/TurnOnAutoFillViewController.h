//
//  TurnOnAutoFillViewController.h
//  Strongbox
//
//  Created by Strongbox on 18/08/2020.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "DatabasePreferences.h"

NS_ASSUME_NONNULL_BEGIN

@interface TurnOnAutoFillViewController : UIViewController

@property (nonatomic, copy) void (^onDone)(void);

@end

NS_ASSUME_NONNULL_END
