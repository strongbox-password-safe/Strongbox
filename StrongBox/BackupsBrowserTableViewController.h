//
//  BackupsBrowserTableViewController.h
//  Strongbox
//
//  Created by Mark on 27/09/2019.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "DatabasePreferences.h"

NS_ASSUME_NONNULL_BEGIN

@interface BackupsBrowserTableViewController : UITableViewController

@property DatabasePreferences* metadata;

@end

NS_ASSUME_NONNULL_END
