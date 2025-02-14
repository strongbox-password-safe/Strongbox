//
//  SyncLogViewController.h
//  Strongbox
//
//  Created by Strongbox on 10/08/2020.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "DatabasePreferences.h"

NS_ASSUME_NONNULL_BEGIN

@interface SyncLogViewController : UITableViewController

+ (UINavigationController*)createWithDatabase:(DatabasePreferences*)database;
@property DatabasePreferences* database;

@end

NS_ASSUME_NONNULL_END
