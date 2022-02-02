//
//  SecondDatabaseListTableViewController.h
//  Strongbox
//
//  Created by Mark on 14/12/2020.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "Model.h"

NS_ASSUME_NONNULL_BEGIN

@interface SecondDatabaseListTableViewController : UITableViewController

@property Model* firstDatabase;

@property BOOL disableReadOnlyDatabases;
@property NSString* customTitle;

@property (nonatomic, copy) void (^onSelectedDatabase)(DatabasePreferences* secondDatabase, __weak UIViewController* vcToDismiss);

@end

NS_ASSUME_NONNULL_END
