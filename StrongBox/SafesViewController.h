//
//  SafesViewController.h
//  StrongBox
//
//  Created by Mark McGuill on 03/06/2014.
//  Copyright (c) 2014 Mark McGuill. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <DZNEmptyDataSet/UIScrollView+EmptyDataSet.h>

@interface SafesViewController : UITableViewController<DZNEmptyDataSetSource, DZNEmptyDataSetDelegate>

@property (strong, nonatomic) IBOutlet UIBarButtonItem *barButtonFlexibleSpace;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *buttonAddSafe;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *buttonUpgrade;
@property (weak, nonatomic) IBOutlet UINavigationItem *navItemHeader;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *buttonToggleEdit;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *barButtonQuickLaunchView;

- (IBAction)onAddSafe:(id)sender;
- (IBAction)onUpgrade:(id)sender;

@property (strong, nonatomic) IBOutlet UIBarButtonItem *buttonTogglePro; // strong outlet because we remove/add from toolbar
- (IBAction)onTogglePro:(id)sender;
- (IBAction)onToggleEdit:(id)sender;

@end
