//
//  StorageBrowserTableViewController.h
//  StrongBox
//
//  Created by Mark on 26/05/2017.
//  Copyright © 2017 Mark McGuill. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "SafeStorageProvider.h"
#import "SafesCollection.h"

@interface StorageBrowserTableViewController : UITableViewController

@property (nonatomic) NSObject *parentFolder;
@property (nonatomic) BOOL existing;
@property (nonatomic) id<SafeStorageProvider> safeStorageProvider;

- (IBAction)onSelectThisFolder:(id)sender;

@property (weak, nonatomic) IBOutlet UIBarButtonItem *buttonSelectThis;
@end
