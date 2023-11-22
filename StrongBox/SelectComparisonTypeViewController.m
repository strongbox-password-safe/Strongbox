//
//  SelectComparisonTypeViewController.m
//  Strongbox
//
//  Created by Strongbox on 02/01/2021.
//  Copyright © 2021 Mark McGuill. All rights reserved.
//

#import "SelectComparisonTypeViewController.h"
#import "DatabaseDiffAndMergeViewController.h"
#import "DatabaseMerger.h"
#import "Alerts.h"

@implementation SelectComparisonTypeViewController

- (BOOL)shouldAutorotate {
    return UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad;
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad ? UIInterfaceOrientationMaskAll : UIInterfaceOrientationMaskPortrait;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    self.navigationController.navigationBarHidden = YES;
    self.navigationController.toolbarHidden = YES;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    BOOL formatGood = (self.firstDatabase.database.originalFormat == kKeePass || self.firstDatabase.database.originalFormat == kKeePass4) &&
        (self.secondDatabase.database.originalFormat == kKeePass || self.secondDatabase.database.originalFormat == kKeePass4);

    if ( !formatGood ) {
        [Alerts info:self
               title:NSLocalizedString(@"diff_compare_partially_supported_title", @"Compare Partially Supported")
             message:NSLocalizedString(@"diff_compare_partially_supported_msg", @"Because of the underlying database format(s) of these databases a full comparison is not possible. Pleaese use the KeePass 2 database format to allow detection of Moves, Deletions, and Group edits.")];
    }
}

- (IBAction)onSimpleCompare:(id)sender {
    [self performSegueWithIdentifier:@"segueToDiffDatabases" sender:@{
        @"mergeCompare" : @(NO),
        @"second" : self.secondDatabase
    }];
}

- (IBAction)onCompareForMerge:(id)sender {
    DatabaseModel* cloneOfFirst = [self.firstDatabase.database clone];
    DatabaseMerger *syncer = [DatabaseMerger mergerFor:cloneOfFirst theirs:self.secondDatabase.database];

    BOOL success = [syncer merge]; 
    if (success) {
        Model* clonedViewModel = [[Model alloc] initWithDatabase:cloneOfFirst metaData:self.firstDatabase.metadata forcedReadOnly:NO isAutoFill:NO];
        
        [self performSegueWithIdentifier:@"segueToDiffDatabases" sender:@{
            @"mergeCompare" : @(YES),
            @"second" : clonedViewModel
        }];
    }
    else {
        [Alerts error:self
                title:NSLocalizedString(@"merge_view_merge_title_error", @"There was an problem merging this database.")
                error:nil
           completion:^{
            self.onDone(NO, nil, nil);
        }];
    }
}

- (IBAction)onCancel:(id)sender {
    self.onDone(NO, nil, nil);
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([segue.identifier isEqualToString:@"segueToDiffDatabases"]) {
        DatabaseDiffAndMergeViewController* vc = segue.destinationViewController;
        
        NSDictionary* params = sender;
        NSNumber* merge = params[@"mergeCompare"];
        Model* secondDb = params[@"second"];
        
        vc.firstDatabase = self.firstDatabase;
        vc.secondDatabase = secondDb;
        vc.isCompareForMerge = merge.boolValue;
        vc.isSyncInitiated = NO;
        
        vc.onDone = self.onDone;
    }
}

@end
