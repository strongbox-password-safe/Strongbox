//
//  KeePassHistoryController.m
//  Strongbox-iOS
//
//  Created by Mark on 07/03/2019.
//  Copyright © 2019 Mark McGuill. All rights reserved.
//

#import "KeePassHistoryController.h"
#import "NodeIconHelper.h"
#import "RecordView.h"
#import "Alerts.h"
#import "ItemDetailsViewController.h"
#import "Settings.h"
#import "BrowseItemCell.h"
#import "Utils.h"
#import "DatabaseSearchAndSorter.h"
#import "BrowseTableViewCellHelper.h"
#import "SharedAppAndAutoFillSettings.h"

@interface KeePassHistoryController ()

@property NSArray<Node*>* items;
@property NSDateFormatter *df;

@property BrowseTableViewCellHelper* cellHelper;

@end

@implementation KeePassHistoryController

- (void)awakeFromNib {
    [super awakeFromNib];
    
    
    
    if(SharedAppAndAutoFillSettings.sharedInstance.hideTips) {
        self.navigationItem.prompt = nil;
    }
    else {
        self.navigationItem.prompt = NSLocalizedString(@"keepass_history_tip", @"Tip: Slide Left for Options or Tap to View");
    }
}

- (void)viewDidLoad {
    [super viewDidLoad];

    self.cellHelper = [[BrowseTableViewCellHelper alloc] initWithModel:self.viewModel tableView:self.tableView];
    
    
    self.tableView.tableFooterView = [UIView new];
    
    self.tableView.estimatedRowHeight = UITableViewAutomaticDimension;
    self.tableView.rowHeight = UITableViewAutomaticDimension;
    
    self.df = [[NSDateFormatter alloc] init];
    self.df.timeStyle = NSDateFormatterShortStyle;
    self.df.dateStyle = NSDateFormatterShortStyle;
    self.df.doesRelativeDateFormatting = YES;
    self.df.locale = NSLocale.currentLocale;
    
    
    
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
    
    NSString *groupLocation = [self.df stringFromDate:node.fields.modified];
    
    return [self.cellHelper getBrowseCellForNode:node
                                       indexPath:indexPath
                               showLargeTotpCell:NO
                               showGroupLocation:NO
                           groupLocationOverride:groupLocation
                                   accessoryType:UITableViewCellAccessoryDisclosureIndicator
                                         noFlags:NO
                             showGroupChildCount:NO
                                subtitleOverride:@(kBrowseItemSubtitleModified)];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    Node* node = self.items[indexPath.row];

    if (@available(iOS 11.0, *)) {
        [self performSegueWithIdentifier:@"HistoryToItemDetails" sender:node];
    }
    else {
        [self performSegueWithIdentifier:@"segueToRecordView" sender:node];
    }
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
    else if ([segue.identifier isEqualToString:@"HistoryToItemDetails"]) {
        Node *record = (Node *)sender;
        
        ItemDetailsViewController *vc = segue.destinationViewController;
        
        vc.createNewItem = NO;
        vc.item = record;
        vc.parentGroup = record.parent;
        vc.readOnly = YES;
        vc.databaseModel = self.viewModel;
    }
}

- (nullable NSArray<UITableViewRowAction *> *)tableView:(UITableView *)tableView editActionsForRowAtIndexPath:(nonnull NSIndexPath *)indexPath {
    UITableViewRowAction *removeAction = [UITableViewRowAction rowActionWithStyle:UITableViewRowActionStyleDestructive
                                                                            title:NSLocalizedString(@"browse_vc_action_delete", @"Delete")
                                                                          handler:^(UITableViewRowAction * _Nonnull action, NSIndexPath * _Nonnull indexPath) {
        [Alerts yesNo:self
                title:NSLocalizedString(@"keepass_history_are_you_sure", @"Are you sure?")
              message:NSLocalizedString(@"keepass_history_are_you_sure_delete_message", @"Are you sure you want to delete this historical item?")
               action:^(BOOL response) {
            if(response) {
                [self onDeleteItem:indexPath];
            }
        }];
    }];
    
    UITableViewRowAction *restoreAction = [UITableViewRowAction rowActionWithStyle:UITableViewRowActionStyleNormal
                                                                             title:NSLocalizedString(@"keepass_history_action_restore", @"Restore")
                                                                           handler:^(UITableViewRowAction * _Nonnull action, NSIndexPath * _Nonnull indexPath) {
        [Alerts yesNo:self
                title:NSLocalizedString(@"keepass_history_are_you_sure", @"Are you sure?")
              message:NSLocalizedString(@"keepass_history_are_you_sure_restore_message", @"Are you sure you want to restore this entry to this historical state?")
               action:^(BOOL response) {
            if(response) {
                [self onRestoreItem:indexPath];
            }
        }];
    }];
    restoreAction.backgroundColor = UIColor.systemBlueColor;
    
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

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return UITableViewAutomaticDimension;  
}

- (CGFloat)tableView:(UITableView *)tableView estimatedHeightForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    /* Return an estimated height or calculate
     * estimated height dynamically on information
     * that makes sense in your case.
     */
    return 60.0f; 
}

@end
