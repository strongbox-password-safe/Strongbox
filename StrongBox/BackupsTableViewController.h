//
//  BackupsTableViewController.h
//  Strongbox
//
//  Created by Mark on 27/09/2019.
//  Copyright © 2019 Mark McGuill. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "SafeMetaData.h"

NS_ASSUME_NONNULL_BEGIN

@interface BackupsTableViewController : UITableViewController

@property SafeMetaData* metadata;

@end

NS_ASSUME_NONNULL_END
