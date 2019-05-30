//
//  SelectItemTableViewController.m
//  Strongbox-iOS
//
//  Created by Mark on 30/05/2019.
//  Copyright © 2019 Mark McGuill. All rights reserved.
//

#import "SelectItemTableViewController.h"

@interface SelectItemTableViewController ()

@end

@implementation SelectItemTableViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self.tableView registerClass:UITableViewCell.class forCellReuseIdentifier:@"selectGenericItemCellIdentifier"];
    
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    self.tableView.tableFooterView = [UIView new];
    [self.tableView reloadData];

    self.clearsSelectionOnViewWillAppear = NO;
}

- (IBAction)onCancel:(id)sender {
    if(self.onDone) {
        self.onDone(NO, -1);
    }
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.items.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"selectGenericItemCellIdentifier" forIndexPath:indexPath];
    
    cell.textLabel.text = self.items[indexPath.row];
    cell.imageView.image = nil;
    cell.accessoryType = self.currentlySelectedIndex == indexPath.row ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if(self.onDone) {
        self.onDone(YES, indexPath.row);
    }
}

@end
