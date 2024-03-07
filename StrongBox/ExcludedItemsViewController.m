//
//  ExcludedItemsViewController.m
//  Strongbox
//
//  Created by Strongbox on 05/06/2020.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import "ExcludedItemsViewController.h"
#import "BrowseTableViewCellHelper.h"
#import "FontManager.h"
#import "UITableView+EmptyDataSet.h"

@interface ExcludedItemsViewController ()

@property BrowseTableViewCellHelper* browseCellHelper;
@property NSArray<Node*> *items;

@end

@implementation ExcludedItemsViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    self.tableView.tableFooterView = UIView.new;
    
    self.browseCellHelper = [[BrowseTableViewCellHelper alloc] initWithModel:self.model tableView:self.tableView];
    
    [self refreshItems];
}

- (NSAttributedString *)getEmptyDatasetTitle
{
    NSString *text = NSLocalizedString(@"audit_drill_down_no_excluded_items_title", @"No Excluded Items");
    
    NSDictionary *attributes = @{NSFontAttributeName:[UIFont preferredFontForTextStyle:UIFontTextStyleHeadline],
                                 NSForegroundColorAttributeName: [UIColor lightGrayColor]};
    
    return [[NSAttributedString alloc] initWithString:text attributes:attributes];
}

- (NSAttributedString *)getEmptyDatasetDescription
{
    NSString *text = NSLocalizedString(@"audit_drill_down_no_excluded_items_subtitle", @"You have not explicitly excluded any items from the audit. You can exclude an item by sliding right on it and tapping the Audit button.");

    NSMutableParagraphStyle *paragraph = [NSMutableParagraphStyle new];
    paragraph.lineBreakMode = NSLineBreakByWordWrapping;
    paragraph.alignment = NSTextAlignmentCenter;

    NSDictionary *attributes = @{NSFontAttributeName: FontManager.sharedInstance.regularFont,
                                 NSForegroundColorAttributeName: [UIColor lightGrayColor],
                                 NSParagraphStyleAttributeName: paragraph};

    return [[NSAttributedString alloc] initWithString:text attributes:attributes];
}

- (void)refreshItems {
    self.items = self.model.excludedFromAuditItems;

    [self.tableView reloadData];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (self.items.count == 0) {
        [self.tableView setEmptyTitle:[self getEmptyDatasetTitle]
                          description:[self getEmptyDatasetDescription]];
    }
    else {
        [self.tableView setEmptyTitle:nil];
    }
    
    return self.items.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    Node* node = self.items[indexPath.row];
    
    UITableViewCell* cell = [self.browseCellHelper getBrowseCellForNode:node
                                                              indexPath:indexPath
                                                      showLargeTotpCell:NO
                                                      showGroupLocation:NO
                                                  groupLocationOverride:nil
                                                          accessoryType:UITableViewCellAccessoryNone
                                                                noFlags:YES];

    return cell;
}

- (nullable NSArray<UITableViewRowAction *> *)tableView:(UITableView *)tableView editActionsForRowAtIndexPath:(nonnull NSIndexPath *)indexPath {
    Node *item = self.items[indexPath.row];
    
    UITableViewRowAction *removeAction = [UITableViewRowAction rowActionWithStyle:UITableViewRowActionStyleDefault
                                                                            title:NSLocalizedString(@"audit_excluded_items_vc_action_unclude", @"Unexclude")
                                                                          handler:^(UITableViewRowAction * _Nonnull action, NSIndexPath * _Nonnull indexPath) {
        [self.model excludeFromAudit:item exclude:NO];
        
        [self refreshItems];
        
        [self.model restartBackgroundAudit];
        
        self.updateDatabase(); 
    }];
    
    removeAction.backgroundColor = UIColor.systemOrangeColor;
    
    return self.model.isReadOnly ? @[] : @[removeAction];
}

@end
