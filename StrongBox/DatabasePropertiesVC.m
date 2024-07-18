//
//  DatabasePropertiesVCTableViewController.m
//  Strongbox
//
//  Created by Strongbox on 19/01/2021.
//  Copyright © 2021 Mark McGuill. All rights reserved.
//

#import "DatabasePropertiesVC.h"
#import "PropertySwitchTableViewCell.h"
#import "DatabasePreferences.h"
#import "AppPreferences.h"
#import "BackupsTableViewController.h"
#import "SyncLogViewController.h"
#import "SelectItemTableViewController.h"
#import "NSArray+Extensions.h"
#import "OfflineDetectedBehaviour.h"
#import "Strongbox-Swift.h"

static NSUInteger const kRowWiFiSyncServiceName = 0;
static NSUInteger const kReadOnlyRow = 1;
static NSUInteger const kQuickLaunchRow = 2;
static NSUInteger const kLazySyncRow = 3;
static NSUInteger const kLazySyncPersistRow = 4;
static NSUInteger const kOfflineDetectedBehaviour = 5;
static NSUInteger const kCouldNotConnectBehaviour = 6;
static NSUInteger const kAlwaysOpenOffline = 7;
static NSUInteger const kConflictResolutionStrategyRow = 8;
static NSUInteger const kBackupsRow = 9;
static NSUInteger const kViewSyncLogRow = 10;

static NSUInteger const kRowCount = 11;

@interface DatabasePropertiesVC ()

@property (readonly) DatabasePreferences* database;

@end

@implementation DatabasePropertiesVC

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self.tableView registerNib:[UINib nibWithNibName:kPropertySwitchTableViewCellId bundle:nil] forCellReuseIdentifier:kPropertySwitchTableViewCellId];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return kRowCount;
}

- (DatabasePreferences*)database {
    return [DatabasePreferences fromUuid:self.databaseUuid];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSString* databaseUuid = self.database.uuid;
    __weak DatabasePropertiesVC* weakSelf = self;
    
    if ( indexPath.row == kReadOnlyRow ) {
        PropertySwitchTableViewCell* cell = [self.tableView dequeueReusableCellWithIdentifier:kPropertySwitchTableViewCellId forIndexPath:indexPath];

        cell.titleLabel.text = NSLocalizedString( @"databases_toggle_read_only_context_menu", @"Read Only");
        cell.subtitleLabel.text = NSLocalizedString ( @"database_properties_subtitle_read_only", @"Do not allow changes/edits to be made to this database when it is open.");
        cell.switchBool.on = self.database.readOnly;
        
        
        cell.onToggledSwitch = ^(BOOL currentState) {
            weakSelf.database.readOnly = currentState;
        };
        
        return cell;
    }
    else if ( indexPath.row == kQuickLaunchRow ) {
        PropertySwitchTableViewCell* cell = [self.tableView dequeueReusableCellWithIdentifier:kPropertySwitchTableViewCellId forIndexPath:indexPath];

        cell.titleLabel.text = NSLocalizedString(@"databases_toggle_quick_launch_context_menu", @"Quick Launch");
        cell.subtitleLabel.text = NSLocalizedString ( @"database_properties_subtitle_quick_launch", @"Automatically Prompt to open this database on App Launch.");
        BOOL isAlreadyQuickLaunch = [AppPreferences.sharedInstance.quickLaunchUuid isEqualToString:databaseUuid];
        cell.switchBool.on = isAlreadyQuickLaunch;
        
        cell.onToggledSwitch = ^(BOOL currentState) {
            if (currentState) {
                AppPreferences.sharedInstance.quickLaunchUuid = databaseUuid;
                [DatabasePreferences notifyDatabaseChanged:databaseUuid];
            }
            else {
                AppPreferences.sharedInstance.quickLaunchUuid = nil;
                [DatabasePreferences notifyDatabaseChanged:databaseUuid];
            }
        };
        
        return cell;
    }
    else if ( indexPath.row == kConflictResolutionStrategyRow ) {
        PropertySwitchTableViewCell* cell = [self.tableView dequeueReusableCellWithIdentifier:kPropertySwitchTableViewCellId forIndexPath:indexPath];

        cell.titleLabel.text = NSLocalizedString ( @"database_properties_title_always_auto_merge", @"Always Auto-Merge");
        cell.subtitleLabel.text = NSLocalizedString ( @"database_properties_subtitle_conflict_resolution", @"When a sync conflict occurs automatically merge without asking.");
        cell.switchBool.on = self.database.conflictResolutionStrategy == kConflictResolutionStrategyAutoMerge;

        cell.onToggledSwitch = ^(BOOL currentState) {
            weakSelf.database.conflictResolutionStrategy = currentState ? kConflictResolutionStrategyAutoMerge : kConflictResolutionStrategyAsk;
        };
        
        return cell;
    }
    else if ( indexPath.row == kLazySyncRow ) {
        PropertySwitchTableViewCell* cell = [self.tableView dequeueReusableCellWithIdentifier:kPropertySwitchTableViewCellId forIndexPath:indexPath];
        
        cell.titleLabel.text = NSLocalizedString(@"lazy_sync_option_title", @"Lazy Sync Mode");
        cell.subtitleLabel.text = NSLocalizedString(@"lazy_sync_option_detail", @"Unlock database first, then attempt to sync.");
        
        cell.switchBool.on = self.database.lazySyncMode;
        
        cell.onToggledSwitch = ^(BOOL currentState) {
            weakSelf.database.lazySyncMode = currentState;
            [weakSelf.tableView reloadData];
        };
        
        return cell;
    }
    else if ( indexPath.row == kLazySyncPersistRow ) {
        PropertySwitchTableViewCell* cell = [self.tableView dequeueReusableCellWithIdentifier:kPropertySwitchTableViewCellId forIndexPath:indexPath];
        
        cell.titleLabel.text = NSLocalizedString(@"lazy_sync_persist_option_title", @"Persistently Lazy (Igonre Errors)");
        cell.subtitleLabel.text = NSLocalizedString(@"lazy_sync_persist_option_detail", @"Keep in Lazy Sync Mode even if an error in sync occurs.");
        
        cell.switchBool.on = self.database.persistLazyEvenLastSyncErrors;
        
        cell.onToggledSwitch = ^(BOOL currentState) {
            weakSelf.database.persistLazyEvenLastSyncErrors = currentState;
            [weakSelf.tableView reloadData];
        };
        
        return cell;
    }
    else if ( indexPath.row == kOfflineDetectedBehaviour ) {
        UITableViewCell* cell = [self.tableView dequeueReusableCellWithIdentifier:@"DatabaseMetadataGenericCell" forIndexPath:indexPath];

        cell.textLabel.text = NSLocalizedString( @"database_properties_title_offline_detected_behaviour", @"Offline Detected Behaviour");
        cell.detailTextLabel.text = stringForOfflineBehaviour(self.database.offlineDetectedBehaviour);
                
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        cell.selectionStyle = UITableViewCellSelectionStyleDefault;
        
        return cell;
    }
    else if ( indexPath.row == kCouldNotConnectBehaviour ) {
        UITableViewCell* cell = [self.tableView dequeueReusableCellWithIdentifier:@"DatabaseMetadataGenericCell" forIndexPath:indexPath];

        cell.textLabel.text = NSLocalizedString( @"database_properties_title_could_not_connect_behaviour", @"Could Not Connect Behaviour");
        
        cell.detailTextLabel.text = stringForCouldNotConnectBehaviour(self.database.couldNotConnectBehaviour);
                
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        cell.selectionStyle = UITableViewCellSelectionStyleDefault;
        
        return cell;
    }
    else if ( indexPath.row == kAlwaysOpenOffline ) {
        PropertySwitchTableViewCell* cell = [self.tableView dequeueReusableCellWithIdentifier:kPropertySwitchTableViewCellId forIndexPath:indexPath];

        cell.titleLabel.text = NSLocalizedString ( @"database_properties_title_always_offline", @"Always Open Offline");
        cell.subtitleLabel.text = NSLocalizedString ( @"database_properties_subtitle_always_offline", @"You can choose to immediately open offline whenever you use this database. No sync will be performed on unlock. A background sync can be performed by pulling down on your Databases list.");
        
        cell.switchBool.on = self.database.forceOpenOffline;

        cell.onToggledSwitch = ^(BOOL currentState) {
            weakSelf.database.forceOpenOffline = currentState;
        };
        
        return cell;
    }
    else if ( indexPath.row == kBackupsRow ) {
        PropertySwitchTableViewCell* cell = [self.tableView dequeueReusableCellWithIdentifier:kPropertySwitchTableViewCellId forIndexPath:indexPath];

        cell.titleLabel.text = NSLocalizedString( @"safes_vc_action_backups", @"Backups");
        cell.subtitleLabel.text = NSLocalizedString ( @"database_properties_subtitle_backups", @"Configure & View local backups." );
        cell.switchBool.hidden = YES;
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        cell.selectionStyle = UITableViewCellSelectionStyleDefault;
        
        return cell;
    }
    else if ( indexPath.row == kViewSyncLogRow ) {
        PropertySwitchTableViewCell* cell = [self.tableView dequeueReusableCellWithIdentifier:kPropertySwitchTableViewCellId forIndexPath:indexPath];

        cell.titleLabel.text = NSLocalizedString( @"safes_vc_action_view_sync_status", @"View Sync Log");
        cell.subtitleLabel.text = NSLocalizedString ( @"database_properties_subtitle_view_sync_log", @"View recent sync details."); 
        cell.switchBool.hidden = YES;
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        cell.selectionStyle = UITableViewCellSelectionStyleDefault;
        
        return cell;
    }
    else if ( indexPath.row == kRowWiFiSyncServiceName ) {
        PropertySwitchTableViewCell* cell = [self.tableView dequeueReusableCellWithIdentifier:kPropertySwitchTableViewCellId forIndexPath:indexPath];

        cell.titleLabel.text = NSLocalizedString(@"wifi_sync_properties_service_name", @"Service Name");
        cell.subtitleLabel.text = self.database.storageProvider == kWiFiSync ? [WiFiSyncStorageProvider.sharedInstance getWifiSyncServerNameFromDatabaseMetadata:self.database] : @"";
        cell.switchBool.hidden = YES;
        cell.accessoryType = UITableViewCellAccessoryNone;
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        
        return cell;
    }

    
    return [super tableView:tableView cellForRowAtIndexPath:indexPath];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    __weak DatabasePropertiesVC* weakSelf = self;
    
    if ( indexPath.row == kBackupsRow ) {
        [self performSegueWithIdentifier:@"segueToBackups" sender:self.database];
    }
    else if ( indexPath.row == kViewSyncLogRow ) {
        [self performSegueWithIdentifier:@"segueToSyncLog" sender:self.database];
    }
    else if ( indexPath.row == kOfflineDetectedBehaviour ) {
        NSArray<NSNumber*>* options = @[@(kOfflineDetectedBehaviourAsk),
                                        @(kOfflineDetectedBehaviourTryConnectThenAsk),
                                        @(kOfflineDetectedBehaviourImmediateOffline)];
        
        NSArray<NSString*>* optionStrings = [options map:^id _Nonnull(NSNumber * _Nonnull obj, NSUInteger idx) {
            return stringForOfflineBehaviour(obj.integerValue);
        }];
        
        [self promptForChoice:NSLocalizedString( @"database_properties_title_offline_detected_behaviour", @"Offline Detected Behaviour")
                      options:optionStrings
         currentlySelectIndex:self.database.offlineDetectedBehaviour
                   completion:^(BOOL success, NSInteger selectedIndex) {
            if ( success ) {
                weakSelf.database.offlineDetectedBehaviour = selectedIndex;
                [self.tableView reloadData];
            }
        }];
    }
    else if ( indexPath.row == kCouldNotConnectBehaviour ) {
        NSArray<NSNumber*>* options = @[@(kCouldNotConnectBehaviourPrompt),
                                        @(kCouldNotConnectBehaviourOpenOffline)];
        
        NSArray<NSString*>* optionStrings = [options map:^id _Nonnull(NSNumber * _Nonnull obj, NSUInteger idx) {
            return stringForCouldNotConnectBehaviour(obj.integerValue);
        }];
        
        [self promptForChoice:NSLocalizedString( @"database_properties_title_could_not_connect_behaviour", @"Could Not Connect Behaviour")
                      options:optionStrings
         currentlySelectIndex:self.database.couldNotConnectBehaviour
                   completion:^(BOOL success, NSInteger selectedIndex) {
            if ( success ) {
                weakSelf.database.couldNotConnectBehaviour = selectedIndex;
                [self.tableView reloadData];
            }
        }];
    }

    [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
}

static NSString* stringForOfflineBehaviour(OfflineDetectedBehaviour mode ) {
    if ( mode == kOfflineDetectedBehaviourAsk ) {
        return NSLocalizedString(@"offline_detected_behaviour_ask_immediately", @"Prompt");
    }
    else if (mode == kOfflineDetectedBehaviourTryConnectThenAsk ) {
        return NSLocalizedString(@"offline_detected_behaviour_try_connect_anyway", @"Try to Connect");
    }
    else {
        return NSLocalizedString(@"offline_detected_behaviour_open_offline", @"Open Offline (No Prompt)");
    }
}

static NSString* stringForCouldNotConnectBehaviour ( CouldNotConnectBehaviour mode ) {
    if ( mode == kCouldNotConnectBehaviourPrompt ) {
        return NSLocalizedString(@"offline_detected_behaviour_ask_immediately", @"Prompt");
    }
    else {
        return NSLocalizedString(@"offline_detected_behaviour_open_offline", @"Open Offline (No Prompt)");
    }
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([segue.identifier isEqualToString:@"segueToBackups"]) {
        UINavigationController* nav = (UINavigationController*)segue.destinationViewController;
        BackupsTableViewController* vc = (BackupsTableViewController*)nav.topViewController;
        vc.metadata = (DatabasePreferences*)sender;
    }
    else if ([segue.identifier isEqualToString:@"segueToSyncLog"]) {
        UINavigationController* nav = (UINavigationController*)segue.destinationViewController;
        SyncLogViewController* vc = (SyncLogViewController*)nav.topViewController;
        vc.database = (DatabasePreferences*)sender;
    }
}

- (void)promptForChoice:(NSString*)title
                options:(NSArray<NSString*>*)items
    currentlySelectIndex:(NSInteger)currentlySelectIndex
              completion:(void(^)(BOOL success, NSInteger selectedIndex))completion {
    UIStoryboard* storyboard = [UIStoryboard storyboardWithName:@"SelectItem" bundle:nil];
    UINavigationController* nav = (UINavigationController*)[storyboard instantiateInitialViewController];
    SelectItemTableViewController *vc = (SelectItemTableViewController*)nav.topViewController;

    vc.groupItems = @[items];
    
    vc.selectedIndexPaths = @[[NSIndexSet indexSetWithIndex:currentlySelectIndex]];
    vc.onSelectionChange = ^(NSArray<NSIndexSet *> * _Nonnull selectedIndices) {
        NSIndexSet* set = selectedIndices.firstObject;
        [self.navigationController popViewControllerAnimated:YES];
        completion(YES, set.firstIndex);
    };
    
    vc.title = title;
    [self.navigationController pushViewController:vc animated:YES];
}

- (IBAction)onDone:(id)sender {
    [self.presentingViewController dismissViewControllerAnimated:YES completion:nil];
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    if ( indexPath.row == kAlwaysOpenOffline ||
         indexPath.row == kOfflineDetectedBehaviour ||
         indexPath.row == kCouldNotConnectBehaviour ||
         indexPath.row == kViewSyncLogRow ||
         indexPath.row == kLazySyncRow ||
         indexPath.row == kLazySyncPersistRow ||
         indexPath.row == kConflictResolutionStrategyRow ||
         indexPath.row == kRowWiFiSyncServiceName
        ) {
        if ( self.database.storageProvider == kLocalDevice || AppPreferences.sharedInstance.disableNetworkBasedFeatures ) {
            return 0.0f;
        }
    }
        
    if ( indexPath.row == kReadOnlyRow ) {
        if ( AppPreferences.sharedInstance.databasesAreAlwaysReadOnly ) {
            return 0.0f;
        }
    }

    if ( indexPath.row == kLazySyncPersistRow && !self.database.lazySyncMode ) {
        return 0.0f;
    }
    
    if ( indexPath.row == kOfflineDetectedBehaviour ||
         indexPath.row == kLazySyncRow ||
         indexPath.row == kLazySyncPersistRow ||
         indexPath.row == kCouldNotConnectBehaviour ) {
        if ( self.database.storageProvider == kWiFiSync ) {
            return 0.0f;
        }
    }
    
    if ( indexPath.row == kOfflineDetectedBehaviour ||
         indexPath.row == kCouldNotConnectBehaviour ) {
        if ( self.database.lazySyncMode ) {
            return 0.0f;
        }
    }
    
    if ( indexPath.row == kRowWiFiSyncServiceName ) {
        if ( self.database.storageProvider != kWiFiSync ) {
            return 0.0f;
        }
    }
    
    return [super tableView:tableView heightForRowAtIndexPath:indexPath];
}

@end
