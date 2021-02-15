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

@property BOOL backupMode;



@property (nullable) Model *viewModel; 



@property (nullable) NSData *encrypted; 
@property (nullable) SafeMetaData* metadata;
@property (nullable) BackupItem* backupItem;

@end

NS_ASSUME_NONNULL_END
