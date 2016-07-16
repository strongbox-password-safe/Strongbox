//
//  SafesViewController.h
//  StrongBox
//
//  Created by Mark McGuill on 03/06/2014.
//  Copyright (c) 2014 Mark McGuill. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface SafesViewController : UITableViewController

@property (weak, nonatomic) IBOutlet UIBarButtonItem *buttonDelete;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *buttonAddSafe;

- (IBAction)onAddSafe:(id)sender;
- (IBAction)onDelete:(id)sender;
- (void)importFromURL:(NSURL *)importURL;

@end
