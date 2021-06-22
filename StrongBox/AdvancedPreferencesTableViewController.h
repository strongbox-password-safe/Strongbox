//
//  AdvancedPreferencesTableViewController.h
//  Strongbox-iOS
//
//  Created by Mark on 27/05/2019.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "StaticDataTableViewController.h"

NS_ASSUME_NONNULL_BEGIN

@interface AdvancedPreferencesTableViewController : StaticDataTableViewController

@property (nonatomic, copy) void (^onDone)(void);

@end

NS_ASSUME_NONNULL_END
