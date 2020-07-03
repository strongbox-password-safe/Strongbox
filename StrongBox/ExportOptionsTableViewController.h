//
//  ExportOptionsTableViewController.h
//  Strongbox-iOS
//
//  Created by Mark on 24/06/2019.
//  Copyright © 2019 Mark McGuill. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "Model.h"
#import "StaticDataTableViewController.h"
#import "BackupItem.h"

NS_ASSUME_NONNULL_BEGIN

@interface ExportOptionsTableViewController : StaticDataTableViewController

@property BOOL backupMode;

// Open / Unlocked Database Export Mode

@property (nullable) Model *viewModel; // TODO: This should be sufficient and remove use of below encrpted/metadata?

// Backup Export mode

@property (nullable) NSData *encrypted;
@property (nullable) SafeMetaData* metadata;
@property (nullable) BackupItem* backupItem;

@end

NS_ASSUME_NONNULL_END
