//
//  StorageBrowserTableViewController.h
//  StrongBox
//
//  Created by Mark on 26/05/2017.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "SafeStorageProvider.h"
#import "AbstractDatabaseFormatAdaptor.h"
#import "SelectStorageProviderController.h"

@interface StorageBrowserTableViewController : UITableViewController

+ (instancetype)instantiateFromStoryboard;

@property (nonatomic) NSObject *parentFolder;
@property (nonatomic) BOOL existing;
@property (nonatomic) BOOL canNotCreateInThisFolder;
@property (nonatomic) id<SafeStorageProvider> safeStorageProvider;
@property (nonatomic, copy) SelectStorageCompletion onDone;

@end
