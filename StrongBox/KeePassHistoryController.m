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

static NSString* const kBrowseItemCell = @"BrowseItemCell";

@interface KeePassHistoryController ()

@property NSArray<Node*>* items;
@property NSDateFormatter *df;

@end

@implementation KeePassHistoryController

- (void)awakeFromNib {
    [super awakeFromNib];
    
    // Tips - Must be done here to avoid jumpy initial animation
    
    if(Settings.sharedInstance.hideTips) {
        self.navigationItem.prompt = nil;
    }
    else {
        self.navigationItem.prompt = NSLocalizedString(@"keepass_history_tip", @"Tip: Slide Left for Options or Tap to View");
    }
}

- (void)viewDidLoad {
    [super viewDidLoad];

    [self.tableView registerNib:[UINib nibWithNibName:kBrowseItemCell bundle:nil] forCellReuseIdentifier:kBrowseItemCell];
    
    // A little trick for removing the cell separators
    self.tableView.tableFooterView = [UIView new];
    
    self.tableView.estimatedRowHeight = UITableViewAutomaticDimension;
    self.tableView.rowHeight = UITableViewAutomaticDimension;
    
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

- (BOOL)isPinned:(Node*)item { // TODO: We need this to be part of the model somehow...
    NSMutableSet<NSString*>* favs = [NSMutableSet setWithArray:self.viewModel.metadata.favourites];
    NSString* sid = [item getSerializationId:self.viewModel.database.format != kPasswordSafe];
    return [favs containsObject:sid];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    Node* node = self.items[indexPath.row];
    BrowseItemCell* cell = [self.tableView dequeueReusableCellWithIdentifier:kBrowseItemCell forIndexPath:indexPath];
    
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;

    NSString* title = self.viewModel.metadata.viewDereferencedFields ? [self dereference:node.title node:node] : node.title;
    UIImage* icon = [NodeIconHelper getIconForNode:node model:self.viewModel];
    
    DatabaseSearchAndSorter* searcher = [[DatabaseSearchAndSorter alloc] initWithDatabase:self.viewModel.database metadata:self.viewModel.metadata];
    NSString* subtitle = [searcher getBrowseItemSubtitle:node];
    
    NSString *groupLocation = [self.df stringFromDate:node.fields.modified];

    [cell setRecord:title
           subtitle:subtitle
               icon:icon
      groupLocation:groupLocation
             pinned:self.viewModel.metadata.showFlagsInBrowse ? [self isPinned:node] : NO
     hasAttachments:self.viewModel.metadata.showFlagsInBrowse ? node.fields.attachments.count : NO
            expired:node.expired
           otpToken:self.viewModel.metadata.hideTotpInBrowse ? nil : node.fields.otpToken
           hideIcon:self.viewModel.metadata.hideIconInBrowse];
    
    return cell;
}

- (NSString*)dereference:(NSString*)text node:(Node*)node {
    return [self.viewModel.database dereference:text node:node];
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

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return UITableViewAutomaticDimension;  // Required for iOS 9 and 10
}

- (CGFloat)tableView:(UITableView *)tableView estimatedHeightForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    /* Return an estimated height or calculate
     * estimated height dynamically on information
     * that makes sense in your case.
     */
    return 60.0f; // Required for iOS 9 and 10
}

@end
