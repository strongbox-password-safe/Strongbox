//
//  SelectItemTableViewController.m
//  Strongbox-iOS
//
//  Created by Mark on 30/05/2019.
//  Copyright © 2019 Mark McGuill. All rights reserved.
//

#import "SelectItemTableViewController.h"
#import <ISMessages/ISMessages.h>

@interface SelectItemTableViewController ()

@property NSMutableIndexSet *selectedIndices;

@end

@implementation SelectItemTableViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.selectedIndices = self.selected.mutableCopy;
    
    [self.tableView registerClass:UITableViewCell.class forCellReuseIdentifier:@"selectGenericItemCellIdentifier"];
    
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    self.tableView.tableFooterView = [UIView new];
    [self.tableView reloadData];

    self.clearsSelectionOnViewWillAppear = NO;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.items.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"selectGenericItemCellIdentifier" forIndexPath:indexPath];
    
    cell.textLabel.text = self.items[indexPath.row];
    cell.imageView.image = nil;
    cell.accessoryType = ([self.selectedIndices containsIndex:indexPath.row]) ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    // Toggle Select and reload row - if allowed
    
    if(self.multipleSelectMode) {
        if(self.multipleSelectDisallowEmpty && self.selectedIndices.count == 1 && indexPath.row == self.selectedIndices.firstIndex) {
            [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
            [ISMessages showCardAlertWithTitle:NSLocalizedString(@"select_item_vc_title_select_one", @"Select One")
                                       message:NSLocalizedString(@"select_item_vc_message_select_one", @"You must select at least one item")
                                      duration:0.5f
                                   hideOnSwipe:YES
                                     hideOnTap:YES
                                     alertType:ISAlertTypeWarning
                                 alertPosition:ISAlertPositionTop
                                       didHide:nil];
            return;
        }
        
        if([self.selectedIndices containsIndex:indexPath.row]) {
            [self.selectedIndices removeIndex:indexPath.row];
        }
        else {
            [self.selectedIndices addIndex:indexPath.row];
        }
    }
    else {
        [self.selectedIndices removeAllIndexes];
        [self.selectedIndices addIndex:indexPath.row];
    }
    
    [self.tableView reloadData];
    
    if(self.onSelectionChanged) {
        self.onSelectionChanged(self.selectedIndices.copy);
    }
}

@end
