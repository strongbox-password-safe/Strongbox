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
#import "EncryptionPreferencesViewController.h"
#import "DatabasePreferences.h"
#import "AutomaticLockingPreferences.h"
#import "CASGTableViewController.h"

@interface DatabasePreferencesController ()

@property (weak, nonatomic) IBOutlet UITableViewCell *cellDatabaseOperations;
@property (weak, nonatomic) IBOutlet UIImageView *imageViewDatabaseOperations;
@property (weak, nonatomic) IBOutlet UITableViewCell *cellViewPreferences;
@property (weak, nonatomic) IBOutlet UIImageView *imageViewPreferences;
@property (weak, nonatomic) IBOutlet UIImageView *imageViewAudit;

@property (weak, nonatomic) IBOutlet UIImageView *imageViewAutoFill;
@property (weak, nonatomic) IBOutlet UITableViewCell *cellAutoFillPreferences;
@property (weak, nonatomic) IBOutlet UITableViewCell *cellConvenienceUnlock;
@property (weak, nonatomic) IBOutlet UILabel *labelConvenienceUnlock;
@property (weak, nonatomic) IBOutlet UIImageView *imageConvenienceUnlock;
@property (weak, nonatomic) IBOutlet UITableViewCell *cellScheduledExport;
@property (weak, nonatomic) IBOutlet UIImageView *imageViewScheduledExport;
@property (weak, nonatomic) IBOutlet UITableViewCell *cellEncryptionSettings;
@property (weak, nonatomic) IBOutlet UIImageView *imageViewEncryptionSettings;

@property (weak, nonatomic) IBOutlet UITableViewCell *cellAutoLocking;
@property (weak, nonatomic) IBOutlet UITableViewCell *cellChangeCreds;
@property (weak, nonatomic) IBOutlet UIImageView *imageViewChangeCreds;
@property (weak, nonatomic) IBOutlet UIImageView *imageViewAutoLock;
@property (weak, nonatomic) IBOutlet UILabel *labelChangeCreds;

@end

@implementation DatabasePreferencesController

- (void)viewDidLoad {
    [super viewDidLoad];







    self.imageViewAudit.tintColor = UIColor.systemOrangeColor;

    self.imageViewPreferences.image = [UIImage imageNamed:@"list"];
    self.imageViewDatabaseOperations.image = [UIImage imageNamed:@"maintenance"];
    self.imageViewAudit.image = [UIImage imageNamed:@"security_checked"];
    self.imageViewAutoFill.image = [UIImage imageNamed:@"password"];
    self.imageViewScheduledExport.image = [UIImage imageNamed:@"delivery"];
    self.imageViewEncryptionSettings.image = [UIImage imageNamed:@"unlock"];

    self.imageViewChangeCreds.image = [UIImage imageNamed:@"key"];
    self.imageViewAutoLock.image = [UIImage imageNamed:@"unlock"];

    if (@available(iOS 13.0, *)) {
        self.imageViewPreferences.image = [UIImage systemImageNamed:@"list.bullet"];
        self.imageViewDatabaseOperations.image = [UIImage systemImageNamed:@"wrench"];
        self.imageViewAudit.image = [UIImage systemImageNamed:@"checkmark.shield"];
        self.imageViewAudit.preferredSymbolConfiguration = [UIImageSymbolConfiguration configurationWithWeight:UIImageSymbolWeightLight];
        self.imageViewEncryptionSettings.image = [UIImage systemImageNamed:@"function"];
        self.imageViewAutoLock.image = [UIImage systemImageNamed:@"lock.rotation.open"];

        if (@available(iOS 14.0, *)) {
            self.imageViewAutoFill.image = [UIImage systemImageNamed:@"rectangle.and.pencil.and.ellipsis"];
            self.imageViewScheduledExport.image = [UIImage systemImageNamed:@"externaldrive.badge.timemachine"];
            self.imageViewChangeCreds.image = [UIImage systemImageNamed:@"key"];
        }
    }
    
    NSString* fmt = [NSString stringWithFormat:NSLocalizedString(@"convenience_unlock_preferences_title_fmt", @"%@ & PIN Codes"), BiometricsManager.sharedInstance.biometricIdName];
    
    self.labelConvenienceUnlock.text = fmt;
    self.imageConvenienceUnlock.image = [BiometricsManager.sharedInstance isFaceId] ? [UIImage imageNamed:@"face_ID"] : [UIImage imageNamed:@"biometric"];
    
    
    
    self.cellChangeCreds.userInteractionEnabled = [self canSetCredentials];
    
    if (@available(iOS 13.0, *)) {
        self.labelChangeCreds.textColor = [self canSetCredentials] ? nil : UIColor.secondaryLabelColor;
    } else {
        self.labelChangeCreds.textColor = [self canSetCredentials] ? nil : UIColor.lightGrayColor;
    }
    
    self.labelChangeCreds.text = self.viewModel.database.originalFormat == kPasswordSafe ?
        NSLocalizedString(@"db_management_change_master_password", @"Change Master Password") :
        NSLocalizedString(@"db_management_change_master_credentials", @"Change Master Credentials");
    
    self.cellChangeCreds.tintColor =  [self canSetCredentials] ? nil : UIColor.lightGrayColor;
}

- (IBAction)onDone:(id)sender {
    self.onDone(NO, self);
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
    else if ( [segue.identifier isEqualToString:@"segueToAutomaticLocking"] ) {
        AutomaticLockingPreferences* vc = (AutomaticLockingPreferences*)segue.destinationViewController;
        vc.viewModel = self.viewModel;
    }
    else if([segue.identifier isEqualToString:@"segueToSetCredentials"]) {
        UINavigationController* nav = (UINavigationController*)segue.destinationViewController;
        CASGTableViewController* scVc = (CASGTableViewController*)nav.topViewController;
        
        scVc.mode = kCASGModeSetCredentials;
        scVc.initialFormat = self.viewModel.database.originalFormat;
        scVc.initialKeyFileBookmark = self.viewModel.metadata.keyFileBookmark;
        scVc.initialYubiKeyConfig = self.viewModel.metadata.contextAwareYubiKeyConfig;
        
        __weak DatabasePreferencesController* weakSelf = self;
        scVc.onDone = ^(BOOL success, CASGParams * _Nullable creds) {
            [weakSelf dismissViewControllerAnimated:YES completion:^{
                if(success) {
                    [weakSelf setCredentials:creds.password
                             keyFileBookmark:creds.keyFileBookmark
                          oneTimeKeyFileData:creds.oneTimeKeyFileData
                                  yubiConfig:creds.yubiKeyConfig];
                }
            }];
        };
    }
    else if ( [segue.identifier isEqualToString:@"segueToScheduledExport"] ) {
        ScheduledExportConfigurationViewController* vc = (ScheduledExportConfigurationViewController*)segue.destinationViewController;
        vc.model = sender;
    }
    else if ( [segue.identifier isEqualToString:@"segueToEncryption"] ) {
        UINavigationController* nav = segue.destinationViewController;
        EncryptionPreferencesViewController* vc = (EncryptionPreferencesViewController*)nav.topViewController;
        vc.onChangedDatabaseEncryptionSettings = self.onChangedDatabaseEncryptionSettings;
        vc.model = self.viewModel;
    }
}

- (BOOL)canSetCredentials {
    return !self.viewModel.isReadOnly;
}

- (void)setCredentials:(NSString*)password
       keyFileBookmark:(NSString*)keyFileBookmark
    oneTimeKeyFileData:(NSData*)oneTimeKeyFileData
            yubiConfig:(YubiKeyHardwareConfiguration*)yubiConfig {
    self.onSetMasterCredentials(password, keyFileBookmark, oneTimeKeyFileData, yubiConfig);
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell* cell = [self.tableView cellForRowAtIndexPath:indexPath];
    
    if ( cell == self.cellAutoFillPreferences ) {
        [self performSegueWithIdentifier:@"segueToAutoFillPreferences" sender:self.viewModel];
    }
    else if ( cell == self.cellChangeCreds ) {
        [self performSegueWithIdentifier:@"segueToSetCredentials" sender:nil];
    }
    else if ( cell == self.cellAutoLocking ) {
        [self performSegueWithIdentifier:@"segueToAutomaticLocking" sender:self.viewModel];
    }
    else if ( cell == self.cellConvenienceUnlock ) {
        [self performSegueWithIdentifier:@"segueToConvenienceUnlock" sender:self.viewModel];
    }
    else if ( cell == self.cellScheduledExport ) {
        [self performSegueWithIdentifier:@"segueToScheduledExport" sender:self.viewModel];
    }
    else if ( cell == self.cellEncryptionSettings ) {
        [self performSegueWithIdentifier:@"segueToEncryption" sender:nil];
    }
    
    [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
}

@end
