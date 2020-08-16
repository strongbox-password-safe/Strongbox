//
//  SyncLogViewController.h
//  Strongbox
//
//  Created by Strongbox on 10/08/2020.
//  Copyright © 2020 Mark McGuill. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "SafeMetaData.h"

NS_ASSUME_NONNULL_BEGIN

@interface SyncLogViewController : UITableViewController

@property SafeMetaData* database;

@end

NS_ASSUME_NONNULL_END
