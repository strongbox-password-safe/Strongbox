//
//  SelectItemTableViewController.m
//  Strongbox-iOS
//
//  Created by Mark on 30/05/2019.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import "SelectItemTableViewController.h"
#import "NSArray+Extensions.h"

#ifndef IS_APP_EXTENSION
#import <ISMessages/ISMessages.h>
#endif

@interface SelectItemTableViewController ()

@property NSArray<NSMutableIndexSet*>* selected;

@end

@implementation SelectItemTableViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.selected = self.selectedIndexPaths ? [self.selectedIndexPaths map:^id _Nonnull(NSIndexSet * _Nonnull obj, NSUInteger idx) {
        return obj.mutableCopy;
    }] : @[NSMutableIndexSet.indexSet];
    
    [self.tableView registerClass:UITableViewCell.class forCellReuseIdentifier:@"selectGenericItemCellIdentifier"];
    
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    self.tableView.tableFooterView = [UIView new];
    [self.tableView reloadData];

    self.clearsSelectionOnViewWillAppear = NO;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (self.groupHeaders && section < self.groupHeaders.count) {
        return self.groupHeaders[section];
    }
    
    return [super tableView:tableView titleForHeaderInSection:section];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return self.groupItems.count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.groupItems[section].count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"selectGenericItemCellIdentifier" forIndexPath:indexPath];
    
    NSArray* sectionItems = self.groupItems[indexPath.section];
    cell.textLabel.text = sectionItems[indexPath.row];
    cell.imageView.image = nil;
    
    NSIndexSet *selectedSet = self.selected[indexPath.section];
    
    cell.accessoryType = ([selectedSet containsIndex:indexPath.row]) ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    

    NSMutableIndexSet* sectionSet = self.selected[indexPath.section];

    if(self.multipleSelectMode) {
        NSUInteger selectedCount = 0;
        for (NSMutableIndexSet *set in self.selected) {
            selectedCount += set.count;
        }

        if (self.multipleSelectDisallowEmpty && selectedCount == 1) {
            if ( indexPath.row == sectionSet.firstIndex ) { 
                [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
                
#ifndef IS_APP_EXTENSION
                [ISMessages showCardAlertWithTitle:NSLocalizedString(@"select_item_vc_title_select_one", @"Select One")
                                           message:NSLocalizedString(@"select_item_vc_message_select_one", @"You must select at least one item")
                                          duration:0.5f
                                       hideOnSwipe:YES
                                         hideOnTap:YES
                                         alertType:ISAlertTypeWarning
                                     alertPosition:ISAlertPositionTop
                                           didHide:nil];
#endif
                return;
            }
        }
        
        if([sectionSet containsIndex:indexPath.row]) {
            [sectionSet removeIndex:indexPath.row];
        }
        else {
            [sectionSet addIndex:indexPath.row];
        }
    }
    else {
        [sectionSet removeAllIndexes];
        [sectionSet addIndex:indexPath.row];
    }
    
    [self.tableView reloadData];
    
    if(self.onSelectionChange) {
        self.onSelectionChange(self.selected); 
    }
}

@end
