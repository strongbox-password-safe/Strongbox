//
//  AdvancedPreferencesTableViewController.h
//  Strongbox-iOS
//
//  Created by Mark on 27/05/2019.
//  Copyright © 2019 Mark McGuill. All rights reserved.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface AdvancedPreferencesTableViewController : UITableViewController

@property (nonatomic, copy) void (^onDone)(void);

@end

NS_ASSUME_NONNULL_END
