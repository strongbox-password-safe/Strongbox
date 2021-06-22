//
//  ExportOptionsTableViewController.h
//  Strongbox-iOS
//
//  Created by Mark on 24/06/2019.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "Model.h"
#import "StaticDataTableViewController.h"
#import "BackupItem.h"

NS_ASSUME_NONNULL_BEGIN

@interface ExportOptionsTableViewController : StaticDataTableViewController

@property BOOL hidePlaintextOptions;
@property (nullable) Model *viewModel;
@property (nonatomic, copy) void (^onDone)(void);

@end

NS_ASSUME_NONNULL_END
