//
//  SelectDatabaseViewController.h
//  Strongbox
//
//  Created by Mark on 14/12/2020.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "DatabasePreferences.h"

NS_ASSUME_NONNULL_BEGIN

@interface SelectDatabaseViewController : UITableViewController

+ (UINavigationController*)fromStoryboard;

@property (nullable) NSString* disableDatabaseUuid;
@property BOOL disableReadOnlyDatabases;
@property NSString* customTitle;

@property (nonatomic, copy) void (^onSelectedDatabase)(DatabasePreferences* _Nullable database, __weak UIViewController* vcToDismiss);

@end

NS_ASSUME_NONNULL_END
