//
//  BrowsePreferencesTableViewController.h
//  Strongbox-iOS
//
//  Created by Mark on 08/06/2019.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "StaticDataTableViewController.h"
#import "AbstractDatabaseFormatAdaptor.h"
#import "DatabasePreferences.h"
#import "Model.h"

NS_ASSUME_NONNULL_BEGIN

@interface BrowsePreferencesTableViewController : StaticDataTableViewController

+ (instancetype)fromStoryboard;

@property Model* model;
@property (nonatomic, copy) void (^onDone)(void);

@end

NS_ASSUME_NONNULL_END
