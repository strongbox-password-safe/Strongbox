//
//  CloudSessionsTableViewController.m
//  Strongbox-iOS
//
//  Created by Mark on 24/05/2019.
//  Copyright © 2019 Mark McGuill. All rights reserved.
//

#import "CloudSessionsTableViewController.h"
#import <ObjectiveDropboxOfficial/ObjectiveDropboxOfficial.h>
#import "GoogleDriveManager.h"
#import "OneDriveStorageProvider.h"
#import "Alerts.h"

@interface CloudSessionsTableViewController ()

@property NSArray* rows;

@end

@implementation CloudSessionsTableViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.navigationController.toolbar.hidden = YES;
    self.navigationController.toolbarHidden = YES;
    
    if (@available(iOS 11.0, *)) {
        self.navigationController.navigationBar.prefersLargeTitles = NO;
    }


    self.tableView.tableFooterView = [UIView new];
    
    self.rows = @[NSLocalizedString(@"cloud_sessions_clear_google", @"Clear Google Drive Session"),
                  NSLocalizedString(@"cloud_sessions_unlink_dropbox", @"Unlink Dropbox"),
                  NSLocalizedString(@"cloud_sessions_clear_onedrive", @"Clear OneDrive Session")];
}

- (IBAction)onDone:(id)sender {
    self.onDone();
}

#pragma mark - Table view data source

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.rows.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cloudSessionsCellIdentifier" forIndexPath:indexPath];
 
    cell.textLabel.text = self.rows[indexPath.row];
    
    
    return cell;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    CGFloat ret = [super tableView:tableView heightForRowAtIndexPath:indexPath];

    if(indexPath.row == 0) {
        return [[GoogleDriveManager sharedInstance] isAuthorized] ? ret : 0;
    }
    else if(indexPath.row == 1) {
        return (DBClientsManager.authorizedClient != nil) ? ret : 0;
    }
    else if(indexPath.row == 2) {
        return [[OneDriveStorageProvider sharedInstance] isSignedIn] ? ret : 0;
    }

    return ret;
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
}

- (void)onUnlinkDropbox {
    if (DBClientsManager.authorizedClient) {
        [Alerts yesNo:self
                title:NSLocalizedString(@"cloud_sessions_prompt_unlink_dropbox_title", @"Unlink Dropbox?")
              message:NSLocalizedString(@"cloud_sessions_prompt_unlink_dropbox_message", @"Are you sure you want to unlink Strongbox from Dropbox?")
               action:^(BOOL response) {
                   if (response) {
                       [DBClientsManager unlinkAndResetClients];
                       
                       [Alerts info:self
                              title:NSLocalizedString(@"cloud_sessions_prompt_dropbox_unlink_success_title", @"Unlink Successful")
                            message:NSLocalizedString(@"cloud_sessions_prompt_dropbox_unlink_success_message", @"You have successfully unlinked Strongbox from Dropbox.")
                         completion:^{
                                [self.navigationController popViewControllerAnimated:YES];
                            }];
                   }
               }];
    }
}

- (void)onSignoutOneDrive {
    if ([OneDriveStorageProvider.sharedInstance isSignedIn]) {
        [Alerts yesNo:self
                title:NSLocalizedString(@"cloud_sessions_prompt_signout_onedrive_title", @"Sign out of OneDrive?")
              message:NSLocalizedString(@"cloud_sessions_prompt_signout_onedrive_message", @"Are you sure you want to sign out of OneDrive?")
               action:^(BOOL response) {
                   if (response) {
                       [OneDriveStorageProvider.sharedInstance signout:^(NSError *error) {
                           dispatch_async(dispatch_get_main_queue(), ^{
                               if(!error) {
                                   
                                   [Alerts info:self
                                          title:NSLocalizedString(@"cloud_sessions_prompt_onedrive_signout_success_title", @"Signout Successful")
                                        message:NSLocalizedString(@"cloud_sessions_prompt_onedrive_signout_success_message", @"You have successfully signed out of OneDrive.")
                                     completion:^{
                                            [self.navigationController popViewControllerAnimated:YES];
                                        }];
                               }
                               else {
                                   [Alerts error:self
                                           title:NSLocalizedString(@"cloud_sessions_prompt_onedrive_signout_error", @"Error Signing out of OneDrive")
                                           error:error];
                               }
                           });
                       }];
                   }
               }];
    }
}

@end
