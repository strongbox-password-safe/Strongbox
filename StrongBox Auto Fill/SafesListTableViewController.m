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
#import "WorkingCopyManager.h"

@interface SafesListTableViewController ()

@property NSArray<DatabasePreferences*> *safes;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *buttonPreferences;

@end

@implementation SafesListTableViewController

+ (UINavigationController *)navControllerfromStoryboard:(SelectAutoFillDatabaseCompletion)completion {
    UIStoryboard *mainStoryboard = [UIStoryboard storyboardWithName:@"MainInterface" bundle:nil];
    UINavigationController* ret = [mainStoryboard instantiateViewControllerWithIdentifier:@"SafesListNavigationController"];
    
    SafesListTableViewController* databasesList = ((SafesListTableViewController*)(ret.topViewController));
    databasesList.completion = completion;
    
    return ret;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    [self setupUi];
    
    [self refreshSafes];

    
    
    if ( AppPreferences.sharedInstance.autoFillQuickLaunchUuid ) {
        DatabasePreferences* database = [self.safes firstOrDefault:^BOOL(DatabasePreferences * _Nonnull obj) {
            return [obj.uuid isEqualToString:AppPreferences.sharedInstance.autoFillQuickLaunchUuid];
        }];
     
        if( database && [self autoFillIsPossibleWithSafe:database]) {
            slog(@"AutoFill - Quick Launch configured and possible... launching db");
            
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [self openDatabase:database];
            });
            return;
        }
    }
}

- (BOOL)autoFillIsPossibleWithSafe:(DatabasePreferences*)safeMetaData {
    if(!safeMetaData.autoFillEnabled) {
        return NO;
    }
        
    return [WorkingCopyManager.sharedInstance isLocalWorkingCacheAvailable:safeMetaData.uuid modified:nil];
}

- (void)setupUi {
    [self.tableView registerNib:[UINib nibWithNibName:kDatabaseCell bundle:nil] forCellReuseIdentifier:kDatabaseCell];
    self.tableView.rowHeight = UITableViewAutomaticDimension;
    self.tableView.separatorStyle = AppPreferences.sharedInstance.showDatabasesSeparator ? UITableViewCellSeparatorStyleSingleLine : UITableViewCellSeparatorStyleNone;
    self.tableView.tableFooterView = [UIView new];
    
    [SVProgressHUD setViewForExtension:self.view];
    
    [self.buttonPreferences setImage:[UIImage systemImageNamed:@"gear"]];
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
    
    BOOL autoFillPossible = [self autoFillIsPossibleWithSafe:safe];

    [cell populateCell:safe disabled:!autoFillPossible autoFill:YES];
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    DatabasePreferences* safe = [self.safes objectAtIndex:indexPath.row];
 
    [self openDatabase:safe];
    
    [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
}

- (IBAction)onCancel:(id)sender {

        self.completion(YES, nil);

}

- (void)openDatabase:(DatabasePreferences*)safe {

        self.completion(NO, safe);

}

@end
