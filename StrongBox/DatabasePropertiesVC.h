//
//  DatabasePropertiesVCTableViewController.h
//  Strongbox
//
//  Created by Strongbox on 19/01/2021.
//  Copyright © 2021 Mark McGuill. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "SafeMetaData.h"

NS_ASSUME_NONNULL_BEGIN

@interface DatabasePropertiesVC : UITableViewController

@property SafeMetaData* database;

@end

NS_ASSUME_NONNULL_END
