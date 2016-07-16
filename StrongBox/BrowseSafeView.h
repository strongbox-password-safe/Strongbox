//
//  OpenSafeView.h
//  StrongBox
//
//  Created by Mark McGuill on 06/06/2014.
//  Copyright (c) 2014 Mark McGuill. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "SafeMetaData.h"
#import "Model.h"

@interface BrowseSafeView : UITableViewController

@property (nonatomic, strong) Model *viewModel;
@property Group* currentGroup;

@property (weak, nonatomic) IBOutlet UIBarButtonItem *buttonAddGroup;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *buttonAddRecord;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *buttonSafeSettings;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *buttonDelete;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *buttonMove;

- (IBAction)onAddGroup:(id)sender;
- (IBAction)onAddRecord:(id)sender;
- (IBAction)onMove:(id)sender;
- (IBAction)onDelete:(id)sender;

@property (weak, nonatomic) IBOutlet UISearchBar *searchBar;

@end
