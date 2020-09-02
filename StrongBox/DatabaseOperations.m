//
//  SafeDetailsView.m
//  StrongBox
//
//  Created by Mark on 09/09/2017.
//  Copyright © 2017 Mark McGuill. All rights reserved.
//

#import "DatabaseOperations.h"
#import "IOsUtils.h"
#import "Alerts.h"
#import "Settings.h"
#import "ISMessages.h"
#import "Utils.h"
#import "KeyFileParser.h"
#import "PinsConfigurationController.h"
#import "AutoFillManager.h"
#import "CASGTableViewController.h"
#import "ExportOptionsTableViewController.h"
#import "AttachmentsPoolViewController.h"
#import "NSArray+Extensions.h"
#import "BiometricsManager.h"
#import "FavIconBulkViewController.h"
#import "YubiManager.h"
#import "BookmarksHelper.h"
#import "OpenSafeSequenceHelper.h"

@interface DatabaseOperations ()

@property (weak, nonatomic) IBOutlet UITableViewCell *cellChangeMasterCredentials;
@property (weak, nonatomic) IBOutlet UITableViewCell *cellExport;
@property (weak, nonatomic) IBOutlet UITableViewCell *cellPrint;
@property (weak, nonatomic) IBOutlet UITableViewCell *cellViewAttachments;
@property (weak, nonatomic) IBOutlet UITableViewCell *cellBulkUpdateFavIcons;

@end

@implementation DatabaseOperations

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // This must be done in code as Interface builder setting is not respected on iPhones
    // until cell gets selected

    self.cellChangeMasterCredentials.imageView.image = [UIImage imageNamed:@"key"];
    self.cellExport.imageView.image = [UIImage imageNamed:@"upload"];
    self.cellPrint.imageView.image = [UIImage imageNamed:@"print"];
    self.cellViewAttachments.imageView.image = [UIImage imageNamed:@"attach"];
    self.cellBulkUpdateFavIcons.imageView.image = [UIImage imageNamed:@"picture"];
    
    [self setupTableView];
}

- (void)setupTableView {
    [self cell:self.cellBulkUpdateFavIcons setHidden:self.viewModel.database.format == kPasswordSafe || self.viewModel.database.format == kKeePass1];
    [self cell:self.cellViewAttachments setHidden:self.viewModel.database.attachments.count == 0];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    self.cellChangeMasterCredentials.userInteractionEnabled = [self canSetCredentials];
    
    if (@available(iOS 13.0, *)) {
        self.cellChangeMasterCredentials.textLabel.textColor = [self canSetCredentials] ? nil : UIColor.secondaryLabelColor;
    } else {
        self.cellChangeMasterCredentials.textLabel.textColor = [self canSetCredentials] ? nil : UIColor.lightGrayColor;
    }
    
    self.cellChangeMasterCredentials.textLabel.text = self.viewModel.database.format == kPasswordSafe ?
    NSLocalizedString(@"db_management_change_master_password", @"Change Master Password") :
    NSLocalizedString(@"db_management_change_master_credentials", @"Change Master Credentials");
    
    self.cellChangeMasterCredentials.tintColor =  [self canSetCredentials] ? nil : UIColor.lightGrayColor;
        
    self.navigationController.toolbarHidden = YES;
    self.navigationController.toolbar.hidden = YES;
    [self.navigationController setNavigationBarHidden:NO];
}

- (IBAction)onDone:(id)sender {
    [self.presentingViewController dismissViewControllerAnimated:YES completion:nil];
}

- (void)onChangeMasterCredentials {
    [self performSegueWithIdentifier:@"segueToSetCredentials" sender:nil];
}

- (BOOL)canSetCredentials {
    return !self.viewModel.isReadOnly;
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if([segue.identifier isEqualToString:@"segueToExportOptions"]) {
        ExportOptionsTableViewController* vc = (ExportOptionsTableViewController*)segue.destinationViewController;
        vc.viewModel = self.viewModel;
    }
    else if([segue.identifier isEqualToString:@"segueToSetCredentials"]) {
        UINavigationController* nav = (UINavigationController*)segue.destinationViewController;
        CASGTableViewController* scVc = (CASGTableViewController*)nav.topViewController;
        
        scVc.mode = kCASGModeSetCredentials;
        scVc.initialFormat = self.viewModel.database.format;
        scVc.initialKeyFileBookmark = self.viewModel.metadata.keyFileBookmark;
        scVc.initialYubiKeyConfig = self.viewModel.metadata.yubiKeyConfig;
        
        scVc.onDone = ^(BOOL success, CASGParams * _Nullable creds) {
            [self dismissViewControllerAnimated:YES completion:^{
                if(success) {
                        [self setCredentials:creds.password
                             keyFileBookmark:creds.keyFileBookmark
                          oneTimeKeyFileData:creds.oneTimeKeyFileData
                                  yubiConfig:creds.yubiKeyConfig];
                }
            }];
        };
    }
    else if ([segue.identifier isEqualToString:@"segueToAttachmentsPool"]) {
        AttachmentsPoolViewController* vc = (AttachmentsPoolViewController*)segue.destinationViewController;
        vc.viewModel = self.viewModel;
    }
}

- (void)setCredentials:(NSString*)password
       keyFileBookmark:(NSString*)keyFileBookmark
    oneTimeKeyFileData:(NSData*)oneTimeKeyFileData
            yubiConfig:(YubiKeyHardwareConfiguration*)yubiConfig {
    CompositeKeyFactors *newCkf = [[CompositeKeyFactors alloc] initWithPassword:password];
    
    // Key File
    
    if(keyFileBookmark != nil || oneTimeKeyFileData != nil) {
        NSError* error;
        NSData* keyFileDigest = getKeyFileDigest(keyFileBookmark, oneTimeKeyFileData, self.viewModel.database.format, &error);
        
        if(keyFileDigest == nil) {
            [Alerts error:self
                    title:NSLocalizedString(@"db_management_error_title_couldnt_change_credentials", @"Could not change credentials")
                    error:error];
            return;
        }
        
        newCkf.keyFileDigest = keyFileDigest;
    }

    // Yubi Key
    
    if (yubiConfig && yubiConfig.mode != kNoYubiKey) {
        newCkf.yubiKeyCR = ^(NSData * _Nonnull challenge, YubiKeyCRResponseBlock  _Nonnull completion) {
            [YubiManager.sharedInstance getResponse:yubiConfig challenge:challenge completion:completion];
        };
    }

    CompositeKeyFactors *rollbackCkf = [self.viewModel.database.compositeKeyFactors clone];
    self.viewModel.database.compositeKeyFactors.password = newCkf.password;
    self.viewModel.database.compositeKeyFactors.keyFileDigest = newCkf.keyFileDigest;
    self.viewModel.database.compositeKeyFactors.yubiKeyCR = newCkf.yubiKeyCR;
    
    [self.viewModel update:self
                   handler:^(BOOL userCancelled, BOOL conflictAndLocalWasChanged, NSError * _Nullable error) {
        if (userCancelled || error || conflictAndLocalWasChanged) {
            // Rollback
            self.viewModel.database.compositeKeyFactors.password = rollbackCkf.password;
            self.viewModel.database.compositeKeyFactors.keyFileDigest = rollbackCkf.keyFileDigest;
            self.viewModel.database.compositeKeyFactors.yubiKeyCR = rollbackCkf.yubiKeyCR;
        
            if (error) {
                [Alerts error:self
                        title:NSLocalizedString(@"db_management_couldnt_change_credentials", @"Could not change credentials")
                        error:error];
            }
        }
        else {
            [self onSuccessfulCredentialsChanged:keyFileBookmark oneTimeKeyFileData:oneTimeKeyFileData yubiConfig:yubiConfig];
        }
    }];
}

- (void)onSuccessfulCredentialsChanged:(NSString*)keyFileBookmark
                    oneTimeKeyFileData:(NSData*)oneTimeKeyFileData
                            yubiConfig:(YubiKeyHardwareConfiguration*)yubiConfig {
    if (self.viewModel.metadata.isTouchIdEnabled && self.viewModel.metadata.isEnrolledForConvenience) {
        if(!oneTimeKeyFileData) {
            self.viewModel.metadata.convenienceMasterPassword = self.viewModel.database.compositeKeyFactors.password;
            self.viewModel.metadata.convenenienceYubikeySecret = self.viewModel.openedWithYubiKeySecret;
            NSLog(@"Keychain updated on Master password changed for touch id enabled and enrolled safe.");
        }
        else {
            // We can't support Convenience unlock with a one time key file...
            self.viewModel.metadata.convenienceMasterPassword = nil;
            self.viewModel.metadata.convenenienceYubikeySecret = nil;
            self.viewModel.metadata.isEnrolledForConvenience = NO;
        }
    }
    
    self.viewModel.metadata.keyFileBookmark = keyFileBookmark;
    self.viewModel.metadata.yubiKeyConfig = yubiConfig;
    [SafesList.sharedInstance update:self.viewModel.metadata];

    [ISMessages showCardAlertWithTitle:self.viewModel.database.format == kPasswordSafe ?
     NSLocalizedString(@"db_management_password_changed", @"Master Password Changed") :
     NSLocalizedString(@"db_management_credentials_changed", @"Master Credentials Changed")
                               message:nil
                              duration:3.f
                           hideOnSwipe:YES
                             hideOnTap:YES
                             alertType:ISAlertTypeSuccess
                         alertPosition:ISAlertPositionTop
                               didHide:nil];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell* cell = [self.tableView cellForRowAtIndexPath:indexPath];
    
    if(cell == self.cellChangeMasterCredentials) {
        [self onChangeMasterCredentials];
    }
    else if (cell == self.cellExport) {
        [self onExport];
    }
    else if (cell == self.cellPrint) {
        [self onPrint];
    }
    else if (cell == self.cellViewAttachments) {
        [self viewAttachments];
    }
    else if (cell == self.cellBulkUpdateFavIcons) {
        [self onBulkUpdateFavIcons];
    }
    
    [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
}

- (void)onBulkUpdateFavIcons {
    [FavIconBulkViewController presentModal:self
                                      nodes:self.viewModel.database.activeRecords
                                     onDone:^(BOOL go, NSDictionary<NSUUID *,UIImage *> * _Nullable selectedFavIcons) {
        [self dismissViewControllerAnimated:YES completion:nil];
        
        if(go && selectedFavIcons) {
            self.onDatabaseBulkIconUpdate(selectedFavIcons); // Browse will take care of updating itself here...
        }
    }];
}

- (void)viewAttachments {
    [self performSegueWithIdentifier:@"segueToAttachmentsPool" sender:nil];
}

- (void)onExport {
    [self performSegueWithIdentifier:@"segueToExportOptions" sender:nil];
}

- (void)onPrint {
    NSString* htmlString = [self.viewModel.database getHtmlPrintString:self.viewModel.metadata.nickName];
    
    UIMarkupTextPrintFormatter *formatter = [[UIMarkupTextPrintFormatter alloc] initWithMarkupText:htmlString];
    
    UIPrintInteractionController.sharedPrintController.printFormatter = formatter;
    
    [UIPrintInteractionController.sharedPrintController presentAnimated:YES completionHandler:nil];
}

@end
