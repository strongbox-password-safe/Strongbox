//
//  ItemDetailsPreferencesViewController.h
//  Strongbox-iOS
//
//  Created by Mark on 09/06/2019.
//  Copyright © 2019 Mark McGuill. All rights reserved.
//

#import "StaticDataTableViewController.h"
#import "SafeMetaData.h"

NS_ASSUME_NONNULL_BEGIN

@interface ItemDetailsPreferencesViewController : StaticDataTableViewController

@property (nonatomic, copy) void (^onPreferencesChanged)(void);
@property SafeMetaData* database;

@end

NS_ASSUME_NONNULL_END
