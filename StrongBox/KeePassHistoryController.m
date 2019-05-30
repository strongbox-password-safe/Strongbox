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

static NSString* const kBrowseItemCell = @"BrowseItemCell";

@interface KeePassHistoryController ()

@property NSArray<Node*>* items;
@property NSDateFormatter *df;

@end

@implementation KeePassHistoryController

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

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    Node* node = self.items[indexPath.row];
    BrowseItemCell* cell = [self.tableView dequeueReusableCellWithIdentifier:kBrowseItemCell forIndexPath:indexPath];
    
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;

    NSString* title = Settings.sharedInstance.viewDereferencedFields ? [self dereference:node.title node:node] : node.title;
    UIImage* icon = [NodeIconHelper getIconForNode:node database:self.viewModel.database];
    
    
    NSString* subtitle = [self getItemSubtitle:node];
    
    NSString *groupLocation = [self.df stringFromDate:node.fields.modified];

    NSString* flags = node.fields.attachments.count > 0 ? @"📎" : @"";
    flags = Settings.sharedInstance.showFlagsInBrowse ? flags : @"";
    
    [cell setRecord:title subtitle:subtitle icon:icon groupLocation:groupLocation flags:flags];
    
    cell.otpLabel.text = @"";
    
    return cell;
}

// This is duplicated - TODO: fix

- (NSString*)getItemSubtitle:(Node*)node {
    switch (Settings.sharedInstance.browseItemSubtitleField) {
        case kNoField:
            return @"";
            break;
        case kUsername:
            return Settings.sharedInstance.viewDereferencedFields ? [self dereference:node.fields.username node:node] : node.fields.username;
            break;
        case kPassword:
            return Settings.sharedInstance.viewDereferencedFields ? [self dereference:node.fields.password node:node] : node.fields.password;
            break;
        case kUrl:
            return Settings.sharedInstance.viewDereferencedFields ? [self dereference:node.fields.url node:node] : node.fields.url;
            break;
        case kEmail:
            return node.fields.email;
            break;
        case kModified:
            return friendlyDateString(node.fields.modified);
        default:
            return @"";
            break;
    }
}

- (NSString*)dereference:(NSString*)text node:(Node*)node {
    return [self.viewModel.database dereference:text node:node];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    Node* node = self.items[indexPath.row];

    if (@available(iOS 11.0, *)) {
        if(Settings.sharedInstance.useOldItemDetailsScene) {
            [self performSegueWithIdentifier:@"segueToRecordView" sender:node];
        }
        else {
            [self performSegueWithIdentifier:@"HistoryToItemDetails" sender:node];
        }
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
