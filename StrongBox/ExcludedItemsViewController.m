//
//  ExcludedItemsViewController.m
//  Strongbox
//
//  Created by Strongbox on 05/06/2020.
//  Copyright © 2020 Mark McGuill. All rights reserved.
//

#import "ExcludedItemsViewController.h"
#import "BrowseTableViewCellHelper.h"
#import <DZNEmptyDataSet/UIScrollView+EmptyDataSet.h>
#import "FontManager.h"

@interface ExcludedItemsViewController () <DZNEmptyDataSetDelegate, DZNEmptyDataSetSource>

@property BrowseTableViewCellHelper* browseCellHelper;
@property NSArray<Node*> *items;

@end

@implementation ExcludedItemsViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    self.tableView.tableFooterView = UIView.new;
    self.tableView.emptyDataSetSource = self;
    self.tableView.emptyDataSetDelegate = self;
    
    self.browseCellHelper = [[BrowseTableViewCellHelper alloc] initWithModel:self.model tableView:self.tableView];
    
    [self refreshItems];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];

    if (self.tableView.contentOffset.y < 0 && self.tableView.emptyDataSetVisible) {
        self.tableView.contentOffset = CGPointZero;
    }
}

- (NSAttributedString *)titleForEmptyDataSet:(UIScrollView *)scrollView
{
    NSString *text = NSLocalizedString(@"audit_drill_down_no_excluded_items_title", @"No Excluded Items");
    
    NSDictionary *attributes = @{NSFontAttributeName:[UIFont preferredFontForTextStyle:UIFontTextStyleHeadline],
                                 NSForegroundColorAttributeName: [UIColor lightGrayColor]};
    
    return [[NSAttributedString alloc] initWithString:text attributes:attributes];
}

- (NSAttributedString *)descriptionForEmptyDataSet:(UIScrollView *)scrollView
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
    self.items = [self.model getExcludedAuditItems];

    [self.tableView reloadData];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
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
        [self.model setItemAuditExclusion:item exclude:NO];
        
        [self refreshItems];
        
        [self.model restartBackgroundAudit];
    }];
    
    removeAction.backgroundColor = UIColor.systemOrangeColor;
    
    return @[removeAction];
}

@end
