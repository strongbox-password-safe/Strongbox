//
//  DatabasesViewPreferencesController.h
//  Strongbox-iOS
//
//  Created by Mark on 30/07/2019.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface DatabasesViewPreferencesController : UITableViewController

@property (nonatomic, copy) void (^onPreferencesChanged)(void);

@end

NS_ASSUME_NONNULL_END
