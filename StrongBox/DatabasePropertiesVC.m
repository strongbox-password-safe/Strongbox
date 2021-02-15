//
//  DatabasePropertiesVCTableViewController.m
//  Strongbox
//
//  Created by Strongbox on 19/01/2021.
//  Copyright © 2021 Mark McGuill. All rights reserved.
//

#import "DatabasePropertiesVC.h"
#import "PropertySwitchTableViewCell.h"
#import "SafesList.h"
#import "SharedAppAndAutoFillSettings.h"
#import "BackupsTableViewController.h"
#import "SyncLogViewController.h"

static NSString* const kPropertySwitchTableViewCellId = @"PropertySwitchTableViewCell";

static NSUInteger const kReadOnlyRow = 0;
static NSUInteger const kQuickLaunchRow = 1;
static NSUInteger const kConflictResolutionStrategyRow = 2;
static NSUInteger const kOfflineDetectedBehaviour = 3;
static NSUInteger const kBackupsRow = 4;
static NSUInteger const kViewSyncLogRow = 5;

static NSUInteger const kRowCount = 6;







@interface DatabasePropertiesVC ()

@end

@implementation DatabasePropertiesVC

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self.tableView registerNib:[UINib nibWithNibName:kPropertySwitchTableViewCellId bundle:nil] forCellReuseIdentifier:kPropertySwitchTableViewCellId];
 
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return kRowCount;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    PropertySwitchTableViewCell* cell = [self.tableView dequeueReusableCellWithIdentifier:kPropertySwitchTableViewCellId forIndexPath:indexPath];

    SafeMetaData* metadata = self.database;
    
    if ( indexPath.row == kReadOnlyRow ) {
        cell.titleLabel.text = NSLocalizedString( @"databases_toggle_read_only_context_menu", @"Read Only");
        cell.subtitleLabel.text = NSLocalizedString ( @"database_properties_subtitle_read_only", @"Do not allow changes/edits to be made to this database when it is open.");
        cell.switchBool.on = metadata.readOnly;
        cell.onToggledSwitch = ^(BOOL currentState) {
            metadata.readOnly = currentState;
            [SafesList.sharedInstance update:metadata];
        };
    }
    else if ( indexPath.row == kQuickLaunchRow ) {
        cell.titleLabel.text = NSLocalizedString(@"databases_toggle_quick_launch_context_menu", @"Quick Launch");
        cell.subtitleLabel.text = NSLocalizedString ( @"database_properties_subtitle_quick_launch", @"Automatically Prompt to open this database on App Launch.");
        BOOL isAlreadyQuickLaunch = [SharedAppAndAutoFillSettings.sharedInstance.quickLaunchUuid isEqualToString:metadata.uuid];
        cell.switchBool.on = isAlreadyQuickLaunch;
        
        cell.onToggledSwitch = ^(BOOL currentState) {
            if (currentState) {
                SharedAppAndAutoFillSettings.sharedInstance.quickLaunchUuid = metadata.uuid;
                [SafesList.sharedInstance update:metadata]; 
            }
            else {
                SharedAppAndAutoFillSettings.sharedInstance.quickLaunchUuid = nil;
                [SafesList.sharedInstance update:metadata]; 
            }
        };
    }
    else if ( indexPath.row == kConflictResolutionStrategyRow ) {
        cell.titleLabel.text = NSLocalizedString ( @"database_properties_title_always_auto_merge", @"Always Auto-Merge");
        cell.subtitleLabel.text = NSLocalizedString ( @"database_properties_subtitle_conflict_resolution", @"When a sync conflict occurs automatically merge without asking.");
        cell.switchBool.on = metadata.conflictResolutionStrategy == kConflictResolutionStrategyAutoMerge;

        cell.onToggledSwitch = ^(BOOL currentState) {
            metadata.conflictResolutionStrategy = currentState ? kConflictResolutionStrategyAutoMerge : kConflictResolutionStrategyAsk;
            [SafesList.sharedInstance update:metadata];
        };
    }
    else if ( indexPath.row == kOfflineDetectedBehaviour ) {
        cell.titleLabel.text = NSLocalizedString ( @"database_properties_title_offline_behaviour", @"Immediate Open Offline Offer");
        cell.subtitleLabel.text = NSLocalizedString ( @"database_properties_subtitle_offline_behaviour", @"Immediately offer to open offline if Strongbox detects you are offline. Alternatively, if you turn this off, Strongbox will try to connect which may take some time."); 
        cell.switchBool.on = metadata.immediateOfflineOfferIfOfflineDetected;

        cell.onToggledSwitch = ^(BOOL currentState) {
            metadata.immediateOfflineOfferIfOfflineDetected = currentState;
            [SafesList.sharedInstance update:metadata];
        };
    }
    else if ( indexPath.row == kBackupsRow ) {
        cell.titleLabel.text = NSLocalizedString( @"safes_vc_action_backups", @"Backups");
        cell.subtitleLabel.text = NSLocalizedString ( @"database_properties_subtitle_backups", @"Configure & View local backups." );
        cell.switchBool.hidden = YES;
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        cell.selectionStyle = UITableViewCellSelectionStyleDefault;
    }
    else if ( indexPath.row == kViewSyncLogRow ) {
        cell.titleLabel.text = NSLocalizedString( @"safes_vc_action_view_sync_status", @"View Sync Log");
        cell.subtitleLabel.text = NSLocalizedString ( @"database_properties_subtitle_view_sync_log", @"View recent sync details."); 
        cell.switchBool.hidden = YES;
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        cell.selectionStyle = UITableViewCellSelectionStyleDefault;
    }

    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if ( indexPath.row == kBackupsRow ) {
        [self performSegueWithIdentifier:@"segueToBackups" sender:self.database];
    }
    else if ( indexPath.row == kViewSyncLogRow ) {
        [self performSegueWithIdentifier:@"segueToSyncLog" sender:self.database];
    }
    
    [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([segue.identifier isEqualToString:@"segueToBackups"]) {
        UINavigationController* nav = (UINavigationController*)segue.destinationViewController;
        BackupsTableViewController* vc = (BackupsTableViewController*)nav.topViewController;
        vc.metadata = (SafeMetaData*)sender;
    }
    else if ([segue.identifier isEqualToString:@"segueToSyncLog"]) {
        UINavigationController* nav = (UINavigationController*)segue.destinationViewController;
        SyncLogViewController* vc = (SyncLogViewController*)nav.topViewController;
        vc.database = (SafeMetaData*)sender;
    }
}

- (IBAction)onDone:(id)sender {
    [self.presentingViewController dismissViewControllerAnimated:YES completion:nil];
}

@end
