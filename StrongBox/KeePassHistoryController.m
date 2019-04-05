//
//  KeePassHistoryController.m
//  Strongbox-iOS
//
//  Created by Mark on 07/03/2019.
//  Copyright © 2019 Mark McGuill. All rights reserved.
//

#import "KeePassHistoryController.h"
#import "KeePassHistoryCell.h"
#import "NodeIconHelper.h"
#import "RecordView.h"
#import "Alerts.h"

@interface KeePassHistoryController ()

@property NSArray<Node*>* items;
@property NSDateFormatter *df;

@end

@implementation KeePassHistoryController

- (void)viewDidLoad {
    [super viewDidLoad];

    // A little trick for removing the cell separators
    self.tableView.tableFooterView = [UIView new];
    
    self.df = [[NSDateFormatter alloc] init];
    self.df.timeStyle = NSDateFormatterShortStyle;
    self.df.dateStyle = NSDateFormatterShortStyle;
    self.df.doesRelativeDateFormatting = YES;
    self.df.locale = NSLocale.currentLocale;
    
    // Sort ascending, oldest to newest
    
    self.items = self.historicalItems == nil ? @[] : [self.historicalItems sortedArrayUsingComparator:^NSComparisonResult(Node*  _Nonnull obj1, Node*  _Nonnull obj2) {
        return [obj1.fields.modified compare:obj2.fields.modified];
    }];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

    self.navigationController.toolbar.hidden = YES;
    self.navigationController.toolbarHidden = YES;

    self.navigationController.navigationBar.hidden = NO;
    [self.navigationController setNavigationBarHidden:NO animated:NO];
    self.navigationController.navigationBarHidden = NO;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.items.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    Node* node = self.items[indexPath.row];

    KeePassHistoryCell *cell = [tableView dequeueReusableCellWithIdentifier:@"KeePassHistoryCell" forIndexPath:indexPath];
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;

    cell.title.text = node.title;
    cell.username.text = node.fields.username;
    cell.icon.image = [NodeIconHelper getIconForNode:node database:self.viewModel.database];
    cell.flags.text = node.fields.attachments.count > 0 ? @"📎" : @"";
    
    NSString *modDateStr = [self.df stringFromDate:node.fields.modified];
    
    cell.date.text = modDateStr;
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    Node* node = self.items[indexPath.row];

    [self performSegueWithIdentifier:@"segueToRecordView" sender:node];
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([segue.identifier isEqualToString:@"segueToRecordView"]) {
        Node *record = (Node *)sender;

        RecordView *vc = segue.destinationViewController;
        vc.record = record;
        vc.parentGroup = record.parent;
        vc.viewModel = self.viewModel;
        vc.isHistoricalEntry = YES;
    }
}

- (nullable NSArray<UITableViewRowAction *> *)tableView:(UITableView *)tableView editActionsForRowAtIndexPath:(nonnull NSIndexPath *)indexPath {
    UITableViewRowAction *removeAction = [UITableViewRowAction rowActionWithStyle:UITableViewRowActionStyleDestructive title:@"Delete" handler:^(UITableViewRowAction * _Nonnull action, NSIndexPath * _Nonnull indexPath) {
        [Alerts yesNo:self title:@"Are you sure?" message:@"Are you sure you want to delete this historical item?" action:^(BOOL response) {
            if(response) {
                [self onDeleteItem:indexPath];
            }
        }];
    }];
    
    UITableViewRowAction *restoreAction = [UITableViewRowAction rowActionWithStyle:UITableViewRowActionStyleNormal title:@"Restore" handler:^(UITableViewRowAction * _Nonnull action, NSIndexPath * _Nonnull indexPath) {
        [Alerts yesNo:self title:@"Are you sure?" message:@"Are you sure you want to restore this entry to this historical state?" action:^(BOOL response) {
            if(response) {
                [self onRestoreItem:indexPath];
            }
        }];
    }];
    restoreAction.backgroundColor = UIColor.blueColor;
    
    return @[removeAction, restoreAction];
}

- (void)onDeleteItem:(NSIndexPath*)indexPath {
    [self.navigationController popViewControllerAnimated:YES];
    
    self.deleteHistoryItem(self.items[indexPath.row]);
}

- (void)onRestoreItem:(NSIndexPath*)indexPath {
    [self.navigationController popViewControllerAnimated:YES];
    
    self.restoreToHistoryItem(self.items[indexPath.row]);
}

@end
