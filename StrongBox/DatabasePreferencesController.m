//
//  DatabasePreferencesController.m
//  Strongbox-iOS
//
//  Created by Mark on 21/03/2020.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import "DatabasePreferencesController.h"
#import "DatabaseOperations.h"
#import "BrowsePreferencesTableViewController.h"
#import "Utils.h"
#import "SelectItemTableViewController.h"
#import "NSArray+Extensions.h"
#import "Alerts.h"
#import "AutoFillManager.h"
#import "PinsConfigurationController.h"
#import "StatisticsPropertiesViewController.h"
#import "AuditConfigurationVcTableViewController.h"
#import "AppPreferences.h"
#import "SyncManager.h"
#import "AutoFillPreferencesViewController.h"
#import "ConvenienceUnlockPreferences.h"
#import "BiometricsManager.h"
#import "ScheduledExportConfigurationViewController.h"

@interface DatabasePreferencesController ()

@property (weak, nonatomic) IBOutlet UILabel *labelDatabaseAutoLockDelay;
@property (weak, nonatomic) IBOutlet UISwitch *switchDatabaseAutoLockEnabled;
@property (weak, nonatomic) IBOutlet UISwitch *switchLockOnDeviceLock;
@property (weak, nonatomic) IBOutlet UISwitch *switchLockDuringEditing;

@property (weak, nonatomic) IBOutlet UITableViewCell *cellDatabaseOperations;
@property (weak, nonatomic) IBOutlet UIImageView *imageViewDatabaseOperations;
@property (weak, nonatomic) IBOutlet UITableViewCell *cellViewPreferences;
@property (weak, nonatomic) IBOutlet UIImageView *imageViewPreferences;
@property (weak, nonatomic) IBOutlet UITableViewCell *cellStats;
@property (weak, nonatomic) IBOutlet UIImageView *imageViewStats;
@property (weak, nonatomic) IBOutlet UITableViewCell *cellDatabaseAutoLockDelay;
@property (weak, nonatomic) IBOutlet UIImageView *imageViewAudit;

@property (weak, nonatomic) IBOutlet UIImageView *imageViewAutoFill;
@property (weak, nonatomic) IBOutlet UITableViewCell *cellAutoFillPreferences;
@property (weak, nonatomic) IBOutlet UITableViewCell *cellConvenienceUnlock;
@property (weak, nonatomic) IBOutlet UILabel *labelConvenienceUnlock;
@property (weak, nonatomic) IBOutlet UIImageView *imageConvenienceUnlock;
@property (weak, nonatomic) IBOutlet UITableViewCell *cellScheduledExport;
@property (weak, nonatomic) IBOutlet UIImageView *imageViewScheduledExport;

@end

@implementation DatabasePreferencesController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.imageViewDatabaseOperations.image = [UIImage imageNamed:@"maintenance"];
    self.imageViewPreferences.image = [UIImage imageNamed:@"list"];
    self.imageViewStats.image = [UIImage imageNamed:@"statistics"];
    self.imageViewAudit.image = [UIImage imageNamed:@"security_checked"];
    self.imageViewAudit.tintColor = UIColor.systemOrangeColor;
    self.imageViewAutoFill.image = [UIImage imageNamed:@"password"];
    self.imageViewScheduledExport.image = [UIImage imageNamed:@"delivery"];
    
    NSString* fmt = [NSString stringWithFormat:NSLocalizedString(@"convenience_unlock_preferences_title_fmt", @"%@ & PIN Codes"), BiometricsManager.sharedInstance.biometricIdName];
    
    self.labelConvenienceUnlock.text = fmt;
    self.imageConvenienceUnlock.image = [BiometricsManager.sharedInstance isFaceId] ? [UIImage imageNamed:@"face_ID"] : [UIImage imageNamed:@"biometric"];

    [self bindUi];
}

- (void)bindUi {
    NSNumber* seconds = self.viewModel.metadata.autoLockTimeoutSeconds ? self.viewModel.metadata.autoLockTimeoutSeconds : @(-1);
    
    if(seconds.integerValue == -1) {
        self.switchDatabaseAutoLockEnabled.on = NO;
        self.labelDatabaseAutoLockDelay.text = NSLocalizedString(@"prefs_vc_setting_disabled", @"Disabled");
        self.cellDatabaseAutoLockDelay.userInteractionEnabled = NO;
    }
    else {
        self.switchDatabaseAutoLockEnabled.on = YES;
        self.labelDatabaseAutoLockDelay.text = [Utils formatTimeInterval:seconds.integerValue];
        self.cellDatabaseAutoLockDelay.userInteractionEnabled = YES;
    }

    self.switchLockOnDeviceLock.on = self.viewModel.metadata.autoLockOnDeviceLock;
    self.switchLockDuringEditing.on = self.viewModel.metadata.lockEvenIfEditing;
}

- (IBAction)onDone:(id)sender {
    self.onDone(NO);
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if([segue.identifier isEqualToString:@"segueToPinsConfiguration"]) {
        PinsConfigurationController* vc = (PinsConfigurationController*)segue.destinationViewController;
        vc.viewModel = self.viewModel;
    }
    else if([segue.identifier isEqualToString:@"segueToOperations"]) {
        DatabaseOperations *vc = (DatabaseOperations *)segue.destinationViewController;
        vc.viewModel = self.viewModel;
        vc.onDatabaseBulkIconUpdate = self.onDatabaseBulkIconUpdate;
        vc.onSetMasterCredentials = self.onSetMasterCredentials;
    }
    else if([segue.identifier isEqualToString:@"segueToViewPreferences"]) {
        BrowsePreferencesTableViewController* vc = (BrowsePreferencesTableViewController*)segue.destinationViewController;
        vc.format = self.viewModel.database.originalFormat;
        vc.databaseMetaData = self.viewModel.metadata;
    }
    else if ([segue.identifier isEqualToString:@"segueToStatistics"]) {
        StatisticsPropertiesViewController* vc = (StatisticsPropertiesViewController*)segue.destinationViewController;
        vc.viewModel = self.viewModel;
    }
    else if ([segue.identifier isEqualToString:@"segueToAudit"]) {
        AuditConfigurationVcTableViewController* vc = (AuditConfigurationVcTableViewController*)segue.destinationViewController;
        vc.model = self.viewModel;
        vc.onDone = self.onDone;
    }
    else if ( [segue.identifier isEqualToString:@"segueToAutoFillPreferences"] ) {
        UINavigationController* nav = segue.destinationViewController;
        AutoFillPreferencesViewController* vc = (AutoFillPreferencesViewController*)nav.topViewController;
        vc.viewModel = sender;
    }
    else if ( [segue.identifier isEqualToString:@"segueToConvenienceUnlock"] ) {
        UINavigationController* nav = segue.destinationViewController;
        ConvenienceUnlockPreferences* vc = (ConvenienceUnlockPreferences*)nav.topViewController;
        vc.viewModel = sender;
    }
    else if ( [segue.identifier isEqualToString:@"segueToScheduledExport"] ) {
        ScheduledExportConfigurationViewController* vc = (ScheduledExportConfigurationViewController*)segue.destinationViewController;
        vc.model = sender;
    }
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell* cell = [self.tableView cellForRowAtIndexPath:indexPath];
    
    if (cell == self.cellDatabaseAutoLockDelay) {
        [self promptForAutoLockTimeout];
    }
    else if ( cell == self.cellAutoFillPreferences ) {
        [self performSegueWithIdentifier:@"segueToAutoFillPreferences" sender:self.viewModel];
    }
    else if ( cell == self.cellConvenienceUnlock ) {
        [self performSegueWithIdentifier:@"segueToConvenienceUnlock" sender:self.viewModel];
    }
    else if ( cell == self.cellScheduledExport ) {
        [self performSegueWithIdentifier:@"segueToScheduledExport" sender:self.viewModel];
    }
    
    [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
}

- (void)promptForAutoLockTimeout {
    [self promptForInteger:NSLocalizedString(@"prefs_vc_auto_lock_database_delay", @"Auto Lock Delay")
                   options:@[@0, @30, @60, @120, @180, @300, @600]
         formatAsIntervals:YES
              currentValue:self.viewModel.metadata.autoLockTimeoutSeconds ? self.viewModel.metadata.autoLockTimeoutSeconds.integerValue : 60
                completion:^(BOOL success, NSInteger selectedValue) {
                    if (success) {
                        self.viewModel.metadata.autoLockTimeoutSeconds = @(selectedValue);
                        [SafesList.sharedInstance update:self.viewModel.metadata];
                    }
                    [self bindUi];
                }];
}

- (IBAction)onSwitchDatabaseAutoLockEnabled:(id)sender {
    self.viewModel.metadata.autoLockTimeoutSeconds = self.switchDatabaseAutoLockEnabled.on ? @(60) : @(-1);
    [SafesList.sharedInstance update:self.viewModel.metadata];
    [self bindUi];
}

- (IBAction)onSwitchLockOnDeviceLock:(id)sender {
    self.viewModel.metadata.autoLockOnDeviceLock = self.switchLockOnDeviceLock.on;
    [SafesList.sharedInstance update:self.viewModel.metadata];
    [self bindUi];
}

- (IBAction)onSwitchLockEvenIfEditing:(id)sender {
    self.viewModel.metadata.lockEvenIfEditing = self.switchLockDuringEditing.on;
    [SafesList.sharedInstance update:self.viewModel.metadata];
    [self bindUi];
}

- (void)promptForInteger:(NSString*)title
                 options:(NSArray<NSNumber*>*)options
       formatAsIntervals:(BOOL)formatAsIntervals
            currentValue:(NSInteger)currentValue
              completion:(void(^)(BOOL success, NSInteger selectedValue))completion {
    
    NSArray<NSString*>* items = [options map:^id _Nonnull(NSNumber * _Nonnull obj, NSUInteger idx) {
        return formatAsIntervals ? [Utils formatTimeInterval:obj.integerValue] : obj.stringValue;
    }];

    NSInteger currentlySelectIndex = [options indexOfObject:@(currentValue)];

    [self promptForChoice:title options:items currentlySelectIndex:currentlySelectIndex completion:^(BOOL success, NSInteger selectedIndex) {
        completion(success, success ? options[selectedIndex].integerValue : -1);
    }];
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


@end
