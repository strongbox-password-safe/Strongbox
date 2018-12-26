//
//  StorageBrowserTableViewController.h
//  StrongBox
//
//  Created by Mark on 26/05/2017.
//  Copyright © 2017 Mark McGuill. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "SafeStorageProvider.h"
#import "AbstractDatabaseFormatAdaptor.h"
#import <DZNEmptyDataSet/UIScrollView+EmptyDataSet.h>

@interface StorageBrowserTableViewController : UITableViewController<DZNEmptyDataSetSource, DZNEmptyDataSetDelegate>

@property (nonatomic) NSObject *parentFolder;
@property (nonatomic) BOOL existing;
@property (nonatomic) id<SafeStorageProvider> safeStorageProvider;
@property (nonatomic) DatabaseFormat format;

- (IBAction)onSelectThisFolder:(id)sender;

@property (weak, nonatomic) IBOutlet UIBarButtonItem *buttonSelectThis;

@end
