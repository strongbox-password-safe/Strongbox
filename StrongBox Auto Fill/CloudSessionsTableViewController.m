//
//  CloudSessionsTableViewController.m
//  Strongbox-iOS
//
//  Created by Mark on 24/05/2019.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#ifndef NO_3RD_PARTY_STORAGE_PROVIDERS

#import "CloudSessionsTableViewController.h"
#import "Alerts.h"
#import "AppPreferences.h"
#import "DropboxV2StorageProvider.h"
#import "GoogleDriveManager.h"
#import "Strongbox-Swift.h"

@interface CloudSessionsTableViewController ()

@property NSArray* rows;

@end

@implementation CloudSessionsTableViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.navigationController.toolbar.hidden = YES;
    self.navigationController.toolbarHidden = YES;
    self.navigationController.navigationBar.prefersLargeTitles = NO;

    self.rows = @[NSLocalizedString(@"cloud_sessions_clear_google", @"Clear Google Drive Session"),
                  NSLocalizedString(@"cloud_sessions_unlink_dropbox", @"Unlink Dropbox"),
                  NSLocalizedString(@"cloud_sessions_clear_onedrive", @"Clear OneDrive Session")];
}

- (IBAction)onDone:(id)sender {
    self.onDone();
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.rows.count;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return NSLocalizedString(@"cloud_sessions_header", @"3rd Party Options");
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    return NSLocalizedString(@"cloud_sessions_footer_text_info", @"The above options are always present. They are not indicative of any existing session. Detecting whether you have an session would require Strongbox to call into 3rd party code which we always try to minimize for security reasons.");
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cloudSessionsCellIdentifier" forIndexPath:indexPath];
 
    cell.textLabel.text = self.rows[indexPath.row];
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    
    if(indexPath.row == 0) {
        [self onSignoutGoogleDrive];
    }
    else if(indexPath.row == 1) {
        [self onUnlinkDropbox];
    }
    else if(indexPath.row == 2) {
        [self onSignoutOneDrive];

    }
    
    [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
}

- (void)onSignoutGoogleDrive {
    [Alerts checkThirdPartyLibOptInOK:self completion:^(BOOL optInOK) {
        if ( !optInOK ) {
            return;
        }
        
        if ([[GoogleDriveManager sharedInstance] isAuthorized]) {
            [Alerts yesNo:self
                    title:NSLocalizedString(@"cloud_sessions_prompt_signout_google_title", @"Sign Out of Google Drive?")
                  message:NSLocalizedString(@"cloud_sessions_prompt_signout_google_message", @"Are you sure you want to sign out of Google Drive?")
                   action:^(BOOL response) {
                       if (response) {
                           [[GoogleDriveManager sharedInstance] signout];
                           
                           [Alerts info:self
                                  title:NSLocalizedString(@"cloud_sessions_prompt_google_signout_success_title", @"Sign Out Successful")
                                message:NSLocalizedString(@"cloud_sessions_prompt_google_signout_success_message", @"You have been successfully been signed out of Google Drive.")
                             completion:^{
                                    [self.navigationController popViewControllerAnimated:YES];
                                }];
                       }
                   }];
        }
        else {
            [Alerts info:self
                   title:NSLocalizedString(@"cloud_sessions_prompt_no_session_found", @"No Cloud Session Found")
                 message:NSLocalizedString(@"cloud_sessions_prompt_no_session_found", @"No Cloud Session Found")];
        }
    }];
}

- (void)onUnlinkDropbox {
    [Alerts checkThirdPartyLibOptInOK:self completion:^(BOOL optInOK) {
        if ( !optInOK ) {
            return;
        }
        
        if ( DropboxV2StorageProvider.sharedInstance.isAuthorized ) {
            [Alerts yesNo:self
                    title:NSLocalizedString(@"cloud_sessions_prompt_unlink_dropbox_title", @"Unlink Dropbox?")
                  message:NSLocalizedString(@"cloud_sessions_prompt_unlink_dropbox_message", @"Are you sure you want to unlink Strongbox from Dropbox?")
                   action:^(BOOL response) {
                       if (response) {
                           [DropboxV2StorageProvider.sharedInstance signOut];
                           
                           [Alerts info:self
                                  title:NSLocalizedString(@"cloud_sessions_prompt_dropbox_unlink_success_title", @"Unlink Successful")
                                message:NSLocalizedString(@"cloud_sessions_prompt_dropbox_unlink_success_message", @"You have successfully unlinked Strongbox from Dropbox.")
                             completion:^{
                                    [self.navigationController popViewControllerAnimated:YES];
                                }];
                       }
                   }];
        }
        else {
            [Alerts info:self
                   title:NSLocalizedString(@"cloud_sessions_prompt_no_session_found", @"No Session Found")
                 message:NSLocalizedString(@"cloud_sessions_prompt_no_session_found", @"No Session Found")];
        }
    }];
}

- (void)onSignoutOneDrive {
    [Alerts checkThirdPartyLibOptInOK:self completion:^(BOOL optInOK) {
        if ( !optInOK ) {
            return;
        }
        
        if ( (YES ) ) { 
            [Alerts yesNo:self
                    title:NSLocalizedString(@"cloud_sessions_prompt_signout_onedrive_title", @"Sign out of OneDrive?")
                  message:NSLocalizedString(@"cloud_sessions_prompt_signout_onedrive_message", @"Are you sure you want to sign out of OneDrive?")
                   action:^(BOOL response) {
                       if (response) {
                           [OneDriveStorageProvider.sharedInstance signOutAll];
                       }
                   }];
        }
        else {
            [Alerts info:self
                   title:NSLocalizedString(@"cloud_sessions_prompt_no_session_found", @"No Session Found")
                 message:NSLocalizedString(@"cloud_sessions_prompt_no_session_found", @"No Session Found")];
        }
    }];
}

@end

#endif

