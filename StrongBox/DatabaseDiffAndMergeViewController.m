//
//  ShowMergeDiffTableViewController.m
//  Strongbox
//
//  Created by Mark on 14/12/2020.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import "DatabaseDiffAndMergeViewController.h"
#import "BrowseTableViewCellHelper.h"
#import "DiffDrilldownTableViewController.h"
#import "NSArray+Extensions.h"
#import "Utils.h"
#import "UIColor+Extensions.h"
#import "Alerts.h"
#import "DatabaseDiffer.h"
#import "SVProgressHUD.h"
#import "AppPreferences.h"

@interface DatabaseDiffAndMergeViewController ()

@property BrowseTableViewCellHelper* browseCellHelperFirstDatabase;
@property BrowseTableViewCellHelper* browseCellHelperSecondDatabase;

@property (weak, nonatomic) IBOutlet UIBarButtonItem *barButtonDone;

@property NSArray<Node*>* willBeAddedOrOnlyInSecond;
@property NSArray<MMcGPair<Node*, Node*>*>* willBeChangedOrEdited;
@property NSArray<Node*>* willChangeHistoryOrHasDifferentHistory;
@property NSArray<MMcGPair<Node*, Node*>*>* willBeMovedOrDifferentLocation;
@property NSArray<Node*>* willBeDeletedOrOnlyInFirst;

@property DiffSummary* diffSummary;

@property (readonly) BOOL mergeIsPossible;

@end

@implementation DatabaseDiffAndMergeViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.navigationController.navigationBarHidden = NO;
    self.navigationController.toolbarHidden = !self.isCompareForMerge; 
    self.navigationItem.hidesBackButton = NO;
    
    self.browseCellHelperFirstDatabase = [[BrowseTableViewCellHelper alloc] initWithModel:self.firstDatabase tableView:self.tableView];
    self.browseCellHelperSecondDatabase = [[BrowseTableViewCellHelper alloc] initWithModel:self.secondDatabase tableView:self.tableView];
        
    if ( !self.isCompareForMerge ) {
        self.navigationItem.title = NSLocalizedString(@"diff_nav_title_comparison_title", @"Comparison Results");
    }
    
    [SVProgressHUD showWithStatus:NSLocalizedString(@"diff_progress_comparing", @"Comparing...")];
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0L), ^{
        self.diffSummary = [self diff];
    
        dispatch_async(dispatch_get_main_queue(), ^{
            [SVProgressHUD dismiss];
            
            if ( self.mergeIsPossible ) {
                NSString* title = self.diffSummary.diffExists ? NSLocalizedString(@"generic_action_merge", @"Merge") : NSLocalizedString(@"generic_done", @"Done");
                
                self.navigationController.navigationBar.topItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:title style:UIBarButtonItemStyleDone target:self action:@selector(onMergeOrDone:)];
            }
            
            [self.tableView reloadData];
        });
    });
}

- (BOOL)mergeIsPossible {
    
    
    
    return self.isCompareForMerge && AppPreferences.sharedInstance.isPro;
}

- (DiffSummary*)diff {
    DiffSummary* summary = [DatabaseDiffer diff:self.firstDatabase.database second:self.secondDatabase.database];
    
    BrowseSortConfiguration* sortConfig = [self.firstDatabase getDefaultSortConfiguration];
    
    
    
    NSArray<Node*>* created = [summary.onlyInSecond map:^id _Nonnull(NSUUID * _Nonnull obj, NSUInteger idx) {
        return [self.secondDatabase.database getItemById:obj];
    }];
    
    self.willBeAddedOrOnlyInSecond = [self.firstDatabase sortItemsForBrowse:created browseSortField:sortConfig.field descending:sortConfig.descending foldersSeparately:sortConfig.foldersOnTop];
        
    
    
    NSArray<Node*>* deleted = [summary.onlyInFirst map:^id _Nonnull(NSUUID * _Nonnull obj, NSUInteger idx) {
        return [self.firstDatabase.database getItemById:obj];
    }];

    self.willBeDeletedOrOnlyInFirst = [self.firstDatabase sortItemsForBrowse:deleted browseSortField:sortConfig.field descending:sortConfig.descending foldersSeparately:sortConfig.foldersOnTop];
    
    
    
    NSArray<Node*>* history = [summary.historicalChanges map:^id _Nonnull(NSUUID * _Nonnull obj, NSUInteger idx) {
        return [self.firstDatabase.database getItemById:obj];
    }];
    
    self.willChangeHistoryOrHasDifferentHistory = [self.firstDatabase sortItemsForBrowse:history browseSortField:sortConfig.field descending:sortConfig.descending foldersSeparately:sortConfig.foldersOnTop];
    
    
    
    self.willBeChangedOrEdited = [[summary.edited map:^id _Nonnull(NSUUID * _Nonnull obj, NSUInteger idx) {
        Node* first = [self.firstDatabase.database getItemById:obj];
        Node* second = [self.secondDatabase.database getItemById:obj];
        return [MMcGPair pairOfA:first andB:second];
    }] sortedArrayUsingComparator:^NSComparisonResult(id  _Nonnull obj1, id  _Nonnull obj2) {
        MMcGPair<Node*, Node*>* first = obj1;
        MMcGPair<Node*, Node*>* second = obj2;
        return finderStringCompare(first.a.title, second.a.title);
    }];
    
    

    self.willBeMovedOrDifferentLocation = [[summary.moved map:^id _Nonnull(NSUUID * _Nonnull obj, NSUInteger idx) {
        Node* first = [self.firstDatabase.database getItemById:obj];
        Node* second = [self.secondDatabase.database getItemById:obj];
        return [MMcGPair pairOfA:first andB:second];
    }] sortedArrayUsingComparator:^NSComparisonResult(id  _Nonnull obj1, id  _Nonnull obj2) {
        MMcGPair<Node*, Node*>* first = obj1;
        MMcGPair<Node*, Node*>* second = obj2;
        return finderStringCompare(first.a.title, second.a.title);
    }];
    
    return summary;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return AppPreferences.sharedInstance.isPro ? 6 : 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (section == 0) {
        return self.diffSummary.databasePropertiesDifferent && AppPreferences.sharedInstance.isPro ? 2 : 1;
    }
    else if (section == 1) {
        return self.willBeChangedOrEdited.count;
    }
    else if (section == 2) {
        return self.willBeAddedOrOnlyInSecond.count;
    }
    else if (section == 3) {
        return self.willBeMovedOrDifferentLocation.count;
    }
    else if (section == 4) {
        return self.willBeDeletedOrOnlyInFirst.count;
    }
    else if (section == 5) {
        return self.willChangeHistoryOrHasDifferentHistory.count;
    }

    return 0;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == 0) {
        UITableViewCell* cell = [self.tableView dequeueReusableCellWithIdentifier:@"diffCellIdentifier"];
        
        if (indexPath.row == 0) {
            if (!self.diffSummary) {
                cell.textLabel.text = NSLocalizedString(@"diff_progress_comparing", @"Comparing...");
                cell.imageView.image = [UIImage imageNamed:@"ok"];
                cell.imageView.tintColor = nil;
                cell.accessoryType = UITableViewCellAccessoryNone;
            }
            else {
                if ( !AppPreferences.sharedInstance.isPro ) {
                    cell.textLabel.text = NSLocalizedString(@"generic_pro_feature_only_please_upgrade", @"Pro feature only. Please Upgrade.");
                    cell.imageView.image = [UIImage imageNamed:@"rocket"];
                    cell.imageView.tintColor = nil;
                    cell.accessoryType = UITableViewCellAccessoryNone;
                }
                else {
                    if (self.isCompareForMerge) {
                        if (self.diffSummary.diffExists) {
                            cell.textLabel.text = [NSString stringWithFormat:NSLocalizedString(@"merge_result_will_lead_to_percentage_difference_fmt", @"Merge will lead to a %0.1f%% difference."), self.diffSummary.differenceMeasure * 100.0f];
                        }
                        else {
                            if ( self.isSyncInitiated ) {
                                cell.textLabel.text = NSLocalizedString(@"merge_result_databases_identical_sync_initiated", @"Merge OK. Tap Done to Continue.");
                            }
                            else {
                                cell.textLabel.text = NSLocalizedString(@"merge_result_databases_identical", @"No changes to merge into first.");
                            }
                        }
                    }
                    else {
                        if (self.diffSummary.diffExists) {
                            cell.textLabel.text = [NSString stringWithFormat:NSLocalizedString(@"diff_result_percentage_difference_fmt", @"Second database is %0.1f%% different."), self.diffSummary.differenceMeasure * 100.0f];
                        }
                        else {
                            cell.textLabel.text = NSLocalizedString(@"diff_result_databases_identical", @"Identical databases.");
                        }
                    }
                    cell.imageView.image = [UIImage imageNamed:@"ok"];
                    cell.imageView.tintColor = [UIColor getSuccessGreenToRedColor:1.0f - self.diffSummary.differenceMeasure];
                    cell.accessoryType = UITableViewCellAccessoryNone;
                }
            }
        }
        else {
            cell.textLabel.text = self.isCompareForMerge ?
                NSLocalizedString(@"merge_result_databases_properties_will_change", @"Some database properties will change.") :
                NSLocalizedString(@"diff_result_databases_properties_different", @"Database properties are different.");
            cell.imageView.image = [UIImage imageNamed:@"list"];
            cell.imageView.tintColor = nil;
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        }
        return cell;
    }
    else if (indexPath.section == 1) {
        MMcGPair<Node*, Node*>* diffPair = self.willBeChangedOrEdited[indexPath.row];
        UITableViewCell* cell = [self.browseCellHelperFirstDatabase getBrowseCellForNode:diffPair.a indexPath:indexPath showLargeTotpCell:NO showGroupLocation:NO groupLocationOverride:nil accessoryType:UITableViewCellAccessoryDisclosureIndicator noFlags:YES];
        
        return cell;
    }
    else if (indexPath.section == 2) {
        Node* node = self.willBeAddedOrOnlyInSecond[indexPath.row];
        
        UITableViewCell* cell = [self.browseCellHelperSecondDatabase getBrowseCellForNode:node indexPath:indexPath showLargeTotpCell:NO showGroupLocation:NO groupLocationOverride:nil accessoryType:UITableViewCellAccessoryNone noFlags:YES];
        
        cell.accessoryType = UITableViewCellAccessoryNone;
        
        return cell;
    }
    else if (indexPath.section == 3) {
        MMcGPair<Node*, Node*>* diffPair = self.willBeMovedOrDifferentLocation[indexPath.row];
        UITableViewCell* cell = [self.browseCellHelperFirstDatabase getBrowseCellForNode:diffPair.a indexPath:indexPath showLargeTotpCell:NO showGroupLocation:NO groupLocationOverride:nil accessoryType:UITableViewCellAccessoryDisclosureIndicator noFlags:YES];
        return cell;
    }
    else if (indexPath.section == 4) {
        Node* node = self.willBeDeletedOrOnlyInFirst[indexPath.row];
        
        UITableViewCell* cell = [self.browseCellHelperFirstDatabase getBrowseCellForNode:node indexPath:indexPath showLargeTotpCell:NO showGroupLocation:NO groupLocationOverride:nil accessoryType:UITableViewCellAccessoryNone noFlags:YES];
        
        cell.accessoryType = UITableViewCellAccessoryNone;
        
        return cell;
    }
    else if (indexPath.section == 5) {
        Node* node = self.willChangeHistoryOrHasDifferentHistory[indexPath.row];
        
        UITableViewCell* cell = [self.browseCellHelperFirstDatabase getBrowseCellForNode:node indexPath:indexPath showLargeTotpCell:NO showGroupLocation:NO groupLocationOverride:nil accessoryType:UITableViewCellAccessoryNone noFlags:YES];
        
        cell.accessoryType = UITableViewCellAccessoryNone;
        
        return cell;
    }

    return [super tableView:self.tableView cellForRowAtIndexPath:indexPath];
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (section == 0) {
        return NSLocalizedString(@"diff_view_section_header_summary", @"Summary");
    }
    else if (section == 1) {
        NSString* fmt = self.isCompareForMerge ? NSLocalizedString(@"diff_view_section_header_entry_will_be_changed_count_fmt", @"Will be Changed (%lu)") : NSLocalizedString(@"diff_view_section_header_entry_differences_fmt", @"Items with Differences (%lu)");
        return [NSString stringWithFormat:fmt, (unsigned long)self.willBeChangedOrEdited.count];
    }
    else if (section == 2) {
        NSString* fmt = self.isCompareForMerge ? NSLocalizedString(@"diff_view_section_header_entry_will_be_added_count_fmt", @"Will be Added (%lu)") : NSLocalizedString(@"diff_view_section_header_only_in_second_fmt", @"Only in Second Database (%lu)");
        return [NSString stringWithFormat:fmt, (unsigned long)self.willBeAddedOrOnlyInSecond.count];
    }
    else if (section == 3) {
        NSString* fmt = self.isCompareForMerge ? NSLocalizedString(@"diff_view_section_header_entry_will_be_moved_count_fmt", @"Will be Moved (%lu)") : NSLocalizedString(@"diff_view_section_header_items_in_different_loc_fmt", @"Items in Different Locations (%lu)");
        return [NSString stringWithFormat:fmt, (unsigned long)self.willBeMovedOrDifferentLocation.count];
    }
    else if (section == 4) {
        NSString* fmt = self.isCompareForMerge ? NSLocalizedString(@"diff_view_section_header_entry_will_be_deleted_count_fmt", @"Will be Deleted (%lu)") : NSLocalizedString(@"diff_view_section_header_only_in_first_fmt", @"Only in First Database (%lu)");
        return [NSString stringWithFormat:fmt, (unsigned long)self.willBeDeletedOrOnlyInFirst.count];
    }
    else if (section == 5) {
        NSString* fmt = self.isCompareForMerge ? NSLocalizedString(@"diff_view_section_header_entry_history_will_change_count_fmt", @"History will Change (%lu)") : NSLocalizedString(@"diff_view_section_header_historical_diffs_fmt", @"Items with Historical Differences (%lu)");
        return [NSString stringWithFormat:fmt, (unsigned long)self.willChangeHistoryOrHasDifferentHistory.count];
    }
    
    return [super tableView:self.tableView titleForHeaderInSection:section];
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    return [super tableView:self.tableView titleForFooterInSection:section];
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    if (section == 1 && !self.willBeChangedOrEdited.count) {
        return 0.1;
    }
    else if (section == 2 && !self.willBeAddedOrOnlyInSecond.count) {
        return 0.1;
    }
    else if (section == 3 && !self.willBeMovedOrDifferentLocation.count) {
        return 0.1;
    }
    else if (section == 4 && !self.willBeDeletedOrOnlyInFirst.count) {
        return 0.1;
    }
    else if (section == 5 && !self.willChangeHistoryOrHasDifferentHistory.count) {
        return 0.1;
    }

    return UITableViewAutomaticDimension;
}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section {
    if (section == 1 && !self.willBeChangedOrEdited.count) {
        return 0.1;
    }
    else if (section == 2 && !self.willBeAddedOrOnlyInSecond.count) {
        return 0.1;
    }
    else if (section == 3 && !self.willBeMovedOrDifferentLocation.count) {
        return 0.1;
    }
    else if (section == 4 && !self.willBeDeletedOrOnlyInFirst.count) {
        return 0.1;
    }
    else if (section == 5 && !self.willChangeHistoryOrHasDifferentHistory.count) {
        return 0.1;
    }

    return UITableViewAutomaticDimension;
}

- (UIView *)sectionFiller {
    static UILabel *emptyLabel = nil;
    if (!emptyLabel) {
        emptyLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        emptyLabel.backgroundColor = [UIColor clearColor];
    }
    return emptyLabel;
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    if (section == 1 && !self.willBeChangedOrEdited.count) {
        return [self sectionFiller];
    }
    else if (section == 2 && !self.willBeAddedOrOnlyInSecond.count) {
        return [self sectionFiller];
    }
    else if (section == 3 && !self.willBeMovedOrDifferentLocation.count) {
        return [self sectionFiller];
    }
    else if (section == 4 && !self.willBeDeletedOrOnlyInFirst.count) {
        return [self sectionFiller];
    }
    else if (section == 5 && !self.willChangeHistoryOrHasDifferentHistory.count) {
        return [self sectionFiller];
    }

    return [super tableView:tableView viewForHeaderInSection:section];
}

- (UIView *)tableView:(UITableView *)tableView viewForFooterInSection:(NSInteger)section {
    if (section == 1 && !self.willBeChangedOrEdited.count) {
        return [self sectionFiller];
    }
    else if (section == 2 && !self.willBeAddedOrOnlyInSecond.count) {
        return [self sectionFiller];
    }
    else if (section == 3 && !self.willBeMovedOrDifferentLocation.count) {
        return [self sectionFiller];
    }
    else if (section == 4 && !self.willBeDeletedOrOnlyInFirst.count) {
        return [self sectionFiller];
    }
    else if (section == 5 && !self.willChangeHistoryOrHasDifferentHistory.count) {
        return [self sectionFiller];
    }

    return [super tableView:tableView viewForFooterInSection:section];
}



- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [self.tableView deselectRowAtIndexPath:indexPath animated:YES];

    MMcGPair<Node*, Node*>* diffPair = nil;

    if (indexPath.section == 0 && indexPath.row == 1) {
        [self performSegueWithIdentifier:@"segueToDiffDrillDown" sender:diffPair];
    }
    else if (indexPath.section == 1) {
        diffPair = self.willBeChangedOrEdited[indexPath.row];
        [self performSegueWithIdentifier:@"segueToDiffDrillDown" sender:diffPair];
    }
    else if (indexPath.section == 3) {
        diffPair = self.willBeMovedOrDifferentLocation[indexPath.row];
        [self performSegueWithIdentifier:@"segueToDiffDrillDown" sender:diffPair];
    }
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ( [segue.identifier isEqualToString:@"segueToDiffDrillDown"] ) {
        DiffDrilldownTableViewController* vc = segue.destinationViewController;
        vc.diffPair = sender;
        vc.firstDatabase = self.firstDatabase;
        vc.secondDatabase = self.secondDatabase;
        vc.isMergeDiff = self.isCompareForMerge;
    }
}

- (IBAction)onCancel:(id)sender {
    self.onDone(NO, nil, nil);
}

- (IBAction)onMergeOrDone:(id)sender {
    self.onDone( self.mergeIsPossible && self.isCompareForMerge, self.firstDatabase, self.secondDatabase );
}

@end
