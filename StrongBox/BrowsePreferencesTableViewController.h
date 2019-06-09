//
//  BrowsePreferencesTableViewController.h
//  Strongbox-iOS
//
//  Created by Mark on 08/06/2019.
//  Copyright © 2019 Mark McGuill. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "StaticDataTableViewController.h"
#import "AbstractDatabaseFormatAdaptor.h"

NS_ASSUME_NONNULL_BEGIN

@interface BrowsePreferencesTableViewController : StaticDataTableViewController

@property DatabaseFormat format;
@property (nonatomic, copy) void (^onPreferencesChanged)(void);

@end

NS_ASSUME_NONNULL_END
