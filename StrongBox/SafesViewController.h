//
//  SafesViewController.h
//  StrongBox
//
//  Created by Mark McGuill on 03/06/2014.
//  Copyright (c) 2014 Mark McGuill. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <StoreKit/StoreKit.h>
#import <DZNEmptyDataSet/UIScrollView+EmptyDataSet.h>

@interface SafesViewController : UITableViewController<SKProductsRequestDelegate, DZNEmptyDataSetSource, DZNEmptyDataSetDelegate>

@property (weak, nonatomic) IBOutlet UIBarButtonItem *buttonTouchID911;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *buttonAddSafe;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *buttonUpgrade;
@property (weak, nonatomic) IBOutlet UINavigationItem *navItemHeader;

- (IBAction)onAddSafe:(id)sender;
- (void)importFromUrlOrEmailAttachment:(NSURL *)importURL;
- (IBAction)onUpgrade:(id)sender;

@property (weak, nonatomic) IBOutlet UIBarButtonItem *buttonTogglePro;
- (IBAction)onTogglePro:(id)sender;

@end
