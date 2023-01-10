//
//  SafesListTableViewController.m
//  Strongbox AutoFill
//
//  Created by Mark on 11/10/2018.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import "SafesListTableViewController.h"
#import "DatabasePreferences.h"
#import "DatabasePreferences.h"
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
#import "SyncManager.h"
#import "NSDate+Extensions.h"
#import "UITableView+EmptyDataSet.h"
#import "IOSCompositeKeyDeterminer.h"
#import "DatabaseUnlocker.h"
#import "DuressActionHelper.h"
#import "AppPreferences.h"

@interface SafesListTableViewController ()

@property NSArray<DatabasePreferences*> *safes;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *buttonPreferences;

@end

@implementation SafesListTableViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    [self setupUi];
    
    [self refreshSafes];

    
    
    if ( AppPreferences.sharedInstance.autoFillQuickLaunchUuid ) {
        DatabasePreferences* database = [self.safes firstOrDefault:^BOOL(DatabasePreferences * _Nonnull obj) {
            return [obj.uuid isEqualToString:AppPreferences.sharedInstance.autoFillQuickLaunchUuid];
        }];
     
        if(database && [[self getInitialViewController] autoFillIsPossibleWithSafe:database]) {
            NSLog(@"AutoFill - Quick Launch configured and possible... launching db");
            
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [self openDatabase:database];
            });
            return;
        }
    }
    
    
    
    if ( AppPreferences.sharedInstance.autoFillAutoLaunchSingleDatabase ) {
        NSArray<DatabasePreferences*> *possibles = [self.safes filter:^BOOL(DatabasePreferences * _Nonnull obj) {
            return [[self getInitialViewController] autoFillIsPossibleWithSafe:obj];
        }];
        
        if ( possibles.count == 1 ) {
            NSLog(@"AutoFill - single enabled database and Auto Proceed switched on... launching db");

            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [self openDatabase:possibles.firstObject];
            });
            return;
        }
    }
}

- (void)setupUi {
    [self.tableView registerNib:[UINib nibWithNibName:kDatabaseCell bundle:nil] forCellReuseIdentifier:kDatabaseCell];
    self.tableView.rowHeight = UITableViewAutomaticDimension;
    self.tableView.separatorStyle = AppPreferences.sharedInstance.showDatabasesSeparator ? UITableViewCellSeparatorStyleSingleLine : UITableViewCellSeparatorStyleNone;
    self.tableView.tableFooterView = [UIView new];
    
    [SVProgressHUD setViewForExtension:self.view];
    
    if (@available(iOS 13.0, *)) { 
        [self.buttonPreferences setImage:[UIImage systemImageNamed:@"gear"]];
    }
}

- (void)refreshSafes {
    self.safes = DatabasePreferences.allDatabases;

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
    [[self getInitialViewController] exitWithUserCancelled:nil];
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
    DatabasePreferences *safe = [self.safes objectAtIndex:indexPath.row];
    
    BOOL autoFillPossible = [[self getInitialViewController] autoFillIsPossibleWithSafe:safe];

    [cell populateCell:safe disabled:!autoFillPossible autoFill:YES];
    
    return cell;
}

- (CredentialProviderViewController *)getInitialViewController {
    return self.rootViewController;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    DatabasePreferences* safe = [self.safes objectAtIndex:indexPath.row];
 
    [self openDatabase:safe];
    
    [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
}

- (void)openDatabase:(DatabasePreferences*)safe {
    IOSCompositeKeyDeterminer* keyDeterminer = [IOSCompositeKeyDeterminer determinerWithViewController:self database:safe isAutoFillOpen:YES isAutoFillQuickTypeOpen:NO biometricPreCleared:NO noConvenienceUnlock:NO];
    [keyDeterminer getCredentials:^(GetCompositeKeyResult result, CompositeKeyFactors * _Nullable factors, BOOL fromConvenience, NSError * _Nullable error) {
        if (result == kGetCompositeKeyResultSuccess) {
            AppPreferences.sharedInstance.autoFillExitedCleanly = NO; 
            DatabaseUnlocker* unlocker = [DatabaseUnlocker unlockerForDatabase:safe viewController:self forceReadOnly:NO isNativeAutoFillAppExtensionOpen:YES offlineMode:YES];
            [unlocker unlockLocalWithKey:factors keyFromConvenience:fromConvenience completion:^(UnlockDatabaseResult result, Model * _Nullable model, NSError * _Nullable error) {
                AppPreferences.sharedInstance.autoFillExitedCleanly = YES;
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

        }
    }];
}

- (void)onUnlockDone:(UnlockDatabaseResult)result model:(Model * _Nullable)model error:(NSError * _Nullable)error {
    NSLog(@"AutoFill: Open Database: Model=[%@] - Error = [%@]", model, error);
    
    if(result == kUnlockDatabaseResultSuccess) {
        [self onUnlockedSuccessfully:model];
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

- (void)onUnlockedSuccessfully:(Model*)model {
    if (model.metadata.autoFillConvenienceAutoUnlockTimeout == -1 ) {
        [self.rootViewController onboardForAutoFillConvenienceAutoUnlock:self database:model.metadata completion:^{
            [self continueUnlockDatabase:model];
        }];
    }
    else {
        [self continueUnlockDatabase:model];
    }
}

- (void)continueUnlockDatabase:(Model*)model  {
    if ( model.metadata.autoFillConvenienceAutoUnlockTimeout > 0 ) {
        model.metadata.autoFillConvenienceAutoUnlockPassword = model.database.ckfs.password;
        [self.rootViewController markLastUnlockedAtTime:model.metadata];
    }

    [self performSegueWithIdentifier:@"toPickCredentialsFromSafes" sender:model];
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
    if ( [segue.identifier isEqualToString:@"toPickCredentialsFromSafes"] ) {
        PickCredentialsTableViewController *vc = segue.destinationViewController;
        vc.model = (Model *)sender;
        vc.rootViewController = self.rootViewController;
    }
}

@end
