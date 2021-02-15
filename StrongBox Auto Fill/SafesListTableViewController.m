//
//  SafesListTableViewController.m
//  Strongbox AutoFill
//
//  Created by Mark on 11/10/2018.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import "SafesListTableViewController.h"
#import "SafeMetaData.h"
#import "SafesList.h"
#import "SafeStorageProviderFactory.h"
#import <AuthenticationServices/AuthenticationServices.h>
#import "CredentialProviderViewController.h"
#import "SVProgressHUD.h"
#import "PickCredentialsTableViewController.h"
#import "NSArray+Extensions.h"
#import "DatabaseCell.h"
#import "Utils.h"
#import "LocalDeviceStorageProvider.h"
#import "FilesAppUrlBookmarkProvider.h"
#import "Alerts.h"
#import "AutoFillSettings.h"
#import "SharedAppAndAutoFillSettings.h"
#import "SyncManager.h"
#import "NSDate+Extensions.h"
#import "UITableView+EmptyDataSet.h"
#import "CompositeKeyDeterminer.h"
#import "DatabaseUnlocker.h"
#import "DuressActionHelper.h"

@interface SafesListTableViewController ()

@property NSArray<SafeMetaData*> *safes;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *buttonPreferences;

@end

@implementation SafesListTableViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    [self setupUi];
    
    [self refreshSafes];

    if(SharedAppAndAutoFillSettings.sharedInstance.quickLaunchUuid) {
        SafeMetaData* database = [self.safes firstOrDefault:^BOOL(SafeMetaData * _Nonnull obj) {
            return [obj.uuid isEqualToString:SharedAppAndAutoFillSettings.sharedInstance.quickLaunchUuid];
        }];
     
        if(database && [[self getInitialViewController] autoFillIsPossibleWithSafe:database]) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [self openDatabase:database];
            });
        }
    }
}

- (void)setupUi {
    [self.tableView registerNib:[UINib nibWithNibName:kDatabaseCell bundle:nil] forCellReuseIdentifier:kDatabaseCell];
    self.tableView.rowHeight = UITableViewAutomaticDimension;
    self.tableView.separatorStyle = SharedAppAndAutoFillSettings.sharedInstance.showDatabasesSeparator ? UITableViewCellSeparatorStyleSingleLine : UITableViewCellSeparatorStyleNone;
    self.tableView.tableFooterView = [UIView new];
    
    [SVProgressHUD setViewForExtension:self.view];
    
    if (@available(iOS 13.0, *)) { 
        [self.buttonPreferences setImage:[UIImage systemImageNamed:@"gear"]];
    }
}

- (void)refreshSafes {
    self.safes = SafesList.sharedInstance.snapshot;

    dispatch_async(dispatch_get_main_queue(), ^(void) {
        [self.tableView reloadData];
    });
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    [self.navigationController setToolbarHidden:NO];
    self.navigationController.toolbar.hidden = NO;
    self.navigationController.toolbarHidden = NO;
}

- (IBAction)onCancel:(id)sender {
    [[self getInitialViewController] exitWithUserCancelled];
}

- (NSAttributedString *)getTitleForEmptyDataSet {
    NSString *text = NSLocalizedString(@"autofill_safes_vc_empty_title", @"You Have No Databases Yet :(");
    
    NSDictionary *attributes = @{NSFontAttributeName: [UIFont boldSystemFontOfSize:18.0f],
                                 NSForegroundColorAttributeName: [UIColor darkGrayColor]};
    
    return [[NSAttributedString alloc] initWithString:text attributes:attributes];
}

- (NSAttributedString *)getDescriptionForEmptyDataSet {
    NSString *text = NSLocalizedString(@"autofill_safes_vc_empty_subtitle", @"To use Strongbox for Password Autofill you need to add a database. You can do this in the Strongbox App.");
    
    NSMutableParagraphStyle *paragraph = [NSMutableParagraphStyle new];
    paragraph.lineBreakMode = NSLineBreakByWordWrapping;
    paragraph.alignment = NSTextAlignmentCenter;
    
    NSDictionary *attributes = @{NSFontAttributeName: [UIFont systemFontOfSize:14.0f],
                                 NSForegroundColorAttributeName: [UIColor lightGrayColor],
                                 NSParagraphStyleAttributeName: paragraph};
    
    return [[NSAttributedString alloc] initWithString:text attributes:attributes];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (self.safes.count == 0) {
        [self.tableView setEmptyTitle:[self getTitleForEmptyDataSet] description:[self getDescriptionForEmptyDataSet]];
    }
    else {
        [self.tableView setEmptyTitle:nil];
    }
    
    return self.safes.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    DatabaseCell *cell = [tableView dequeueReusableCellWithIdentifier:kDatabaseCell forIndexPath:indexPath];
    SafeMetaData *safe = [self.safes objectAtIndex:indexPath.row];
    
    BOOL autoFillPossible = [[self getInitialViewController] autoFillIsPossibleWithSafe:safe];

    [cell populateCell:safe disabled:!autoFillPossible autoFill:YES];
    
    return cell;
}

- (CredentialProviderViewController *)getInitialViewController {
    return self.rootViewController;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    SafeMetaData* safe = [self.safes objectAtIndex:indexPath.row];
 
    [self openDatabase:safe];
    
    [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
}

- (void)openDatabase:(SafeMetaData*)safe {
    CompositeKeyDeterminer* keyDeterminer = [CompositeKeyDeterminer determinerWithViewController:self database:safe isAutoFillOpen:YES isAutoFillQuickTypeOpen:NO biometricPreCleared:NO noConvenienceUnlock:NO];
    [keyDeterminer getCredentials:^(GetCompositeKeyResult result, CompositeKeyFactors * _Nullable factors, BOOL fromConvenience, NSError * _Nullable error) {
        if (result == kGetCompositeKeyResultSuccess) {
            AutoFillSettings.sharedInstance.autoFillExitedCleanly = NO; 
            DatabaseUnlocker* unlocker = [DatabaseUnlocker unlockerForDatabase:safe viewController:self forceReadOnly:NO isAutoFillOpen:YES offlineMode:YES];
            [unlocker unlockLocalWithKey:factors keyFromConvenience:fromConvenience completion:^(UnlockDatabaseResult result, Model * _Nullable model, NSError * _Nullable error) {
                AutoFillSettings.sharedInstance.autoFillExitedCleanly = YES;
                [self onUnlockDone:result model:model error:error];
            }];
        }
        else if (result == kGetCompositeKeyResultError) {
            [self messageErrorAndExit:error];
        }
        else if (result == kGetCompositeKeyResultDuressIndicated) {
            [DuressActionHelper performDuressAction:self database:safe isAutoFillOpen:NO completion:^(UnlockDatabaseResult result, Model * _Nullable model, NSError * _Nullable error) {
                [self onUnlockDone:result model:model error:error];
                [self refreshSafes]; 
            }];
        }
        else {
            [self onCancel:nil];
        }
    }];
}

- (void)onUnlockDone:(UnlockDatabaseResult)result model:(Model * _Nullable)model error:(NSError * _Nullable)error {
    NSLog(@"AutoFill: Open Database: Model=[%@] - Error = [%@]", model, error);
    
    if(result == kUnlockDatabaseResultSuccess) {
        [self performSegueWithIdentifier:@"toPickCredentialsFromSafes" sender:model];
    }
    else if(result == kUnlockDatabaseResultUserCancelled || result == kUnlockDatabaseResultViewDebugSyncLogRequested) {
        [self onCancel:nil];
    }
    else if (result == kUnlockDatabaseResultIncorrectCredentials) {
        
        NSLog(@"INCORRECT CREDENTIALS - kUnlockDatabaseResultIncorrectCredentials");
        [[self getInitialViewController] exitWithErrorOccurred:error ? error : [Utils createNSError:@"Could not open database" errorCode:-1]];
    }
    else if (result == kUnlockDatabaseResultError) {
        [self messageErrorAndExit:error];
    }
}

- (void)messageErrorAndExit:(NSError*)error {
    [Alerts error:self
            title:NSLocalizedString(@"open_sequence_problem_opening_title", @"There was a problem opening the database.")
            error:error
       completion:^{
        [[self getInitialViewController] exitWithErrorOccurred:error];
    }];
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([segue.identifier isEqualToString:@"toPickCredentialsFromSafes"]) {
        PickCredentialsTableViewController *vc = segue.destinationViewController;
        vc.model = (Model *)sender;
        vc.rootViewController = self.rootViewController;
    }
}

@end
