//
//  ShowMergeDiffTableViewController.m
//  Strongbox
//
//  Created by Mark on 14/12/2020.
//  Copyright © 2020 Mark McGuill. All rights reserved.
//

#import "ShowMergeDiffTableViewController.h"
#import "DatabaseSynchronizer.h"
#import "BrowseTableViewCellHelper.h"
#import "DiffDrilldownTableViewController.h"
#import "NSArray+Extensions.h"
#import "Utils.h"

@interface ShowMergeDiffTableViewController ()

@property SyncDiffReport* diffReport;
@property BrowseTableViewCellHelper* browseCellHelperFirstDatabase;
@property BrowseTableViewCellHelper* browseCellHelperSecondDatabase;

@property NSArray<Pair<Node*, Node*>*>* sortedDiffs;

@end

@implementation ShowMergeDiffTableViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.navigationController.navigationBarHidden = NO;

    self.browseCellHelperFirstDatabase = [[BrowseTableViewCellHelper alloc] initWithModel:self.firstDatabase tableView:self.tableView];
    self.browseCellHelperSecondDatabase = [[BrowseTableViewCellHelper alloc] initWithModel:self.secondDatabase tableView:self.tableView];
    
    DatabaseSynchronizer *syncer = [DatabaseSynchronizer newSynchronizerFor:self.firstDatabase.database theirs:self.secondDatabase.database];
    self.diffReport = [syncer getDiff];
    
    self.sortedDiffs = [self.diffReport.differentFromOurs sortedArrayUsingComparator:^NSComparisonResult(id  _Nonnull obj1, id  _Nonnull obj2) {
        Pair<Node*, Node*>* first = obj1;
        Pair<Node*, Node*>* second = obj2;
        
        return finderStringCompare(first.a.title, second.a.title);
    }];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 4;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (section == 0) { 
        return 1;
    }
    else if (section == 1) { 
        return self.sortedDiffs.count;
    }
    else if (section == 2) { 
        return self.diffReport.onlyInTheirs.count;
    }
    else if (section == 3) { 
        return 0;
    }

    return 0;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == 0) {
        UITableViewCell* cell = [self.tableView dequeueReusableCellWithIdentifier:@"diffCellIdentifier"];
        cell.textLabel.text = @"Cool!"; 
        cell.imageView.image = [UIImage imageNamed:@"ok"];
        cell.imageView.tintColor = UIColor.systemGreenColor;
        return cell;
    }
    else if (indexPath.section == 1) {
        Pair<Node*, Node*>* diffPair = self.sortedDiffs[indexPath.row];
        UITableViewCell* cell = [self.browseCellHelperFirstDatabase getBrowseCellForNode:diffPair.a indexPath:indexPath showLargeTotpCell:NO showGroupLocation:NO groupLocationOverride:nil accessoryType:UITableViewCellAccessoryDisclosureIndicator noFlags:YES];
        
        return cell;
    }
    else if (indexPath.section == 2) {
        Node* node = self.diffReport.onlyInTheirs[indexPath.row];
        return [self.browseCellHelperSecondDatabase getBrowseCellForNode:node indexPath:indexPath showLargeTotpCell:NO showGroupLocation:NO];
    }

    return [super tableView:self.tableView cellForRowAtIndexPath:indexPath];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    if (indexPath.section == 1) {
        Pair<Node*, Node*>* diffPair = self.sortedDiffs[indexPath.row];
        
        [self performSegueWithIdentifier:@"segueToDiffDrillDown" sender:diffPair];
    }
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (section == 0) { 
        return @"Summary"; 
    }
    else if (section == 1) { 
        return [NSString stringWithFormat:@"Edited Items (%lu)", (unsigned long)self.sortedDiffs.count]; 
    }
    else if (section == 2) {
        return [NSString stringWithFormat:@"New Items to be Added (%lu)", (unsigned long)self.diffReport.onlyInTheirs.count]; 
    }
    else if (section == 3) {
        return [NSString stringWithFormat:@"Database Property Changes (%lu)", (unsigned long)self.diffReport.onlyInTheirs.count]; 
    }
    
    return [super tableView:self.tableView titleForHeaderInSection:section];
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    return [super tableView:self.tableView titleForFooterInSection:section];
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ( [segue.identifier isEqualToString:@"segueToDiffDrillDown"] ) {
        DiffDrilldownTableViewController* vc = segue.destinationViewController;
        vc.diffPair = sender;
        vc.firstDatabase = self.firstDatabase;
        vc.secondDatabase = self.secondDatabase;
    }
}

- (IBAction)onCancel:(id)sender {
    self.onDone(YES);
}

- (IBAction)onMerge:(id)sender {

}

@end
