//
//  SafeDetailsView.h
//  StrongBox
//
//  Created by Mark on 09/09/2017.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "Model.h"
#import "StaticDataTableViewController.h"
#import "YubiKeyHardwareConfiguration.h"

NS_ASSUME_NONNULL_BEGIN

@interface AdvancedDatabaseSettings : StaticDataTableViewController

+ (instancetype)fromStoryboard;

@property (nonatomic) Model *viewModel;

@property (nonatomic, copy) void (^onDatabaseBulkIconUpdate)(NSDictionary<NSUUID *, NodeIcon *> * _Nullable selectedFavIcons);

@end

NS_ASSUME_NONNULL_END
