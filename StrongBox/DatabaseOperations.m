//
//  SafeDetailsView.m
//  StrongBox
//
//  Created by Mark on 09/09/2017.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import "DatabaseOperations.h"
#import "IOsUtils.h"
#import "Alerts.h"
//#import "Settings.h"
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
#import "KeyFileHelper.h"

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
    
    
    

    self.cellChangeMasterCredentials.imageView.image = [UIImage imageNamed:@"key"];
    self.cellExport.imageView.image = [UIImage imageNamed:@"upload"];
    self.cellPrint.imageView.image = [UIImage imageNamed:@"print"];
    self.cellViewAttachments.imageView.image = [UIImage imageNamed:@"attach"];
    self.cellBulkUpdateFavIcons.imageView.image = [UIImage imageNamed:@"picture"];
    
    [self setupTableView];
}

- (void)setupTableView {
    [self cell:self.cellBulkUpdateFavIcons setHidden:self.viewModel.database.originalFormat == kPasswordSafe || self.viewModel.database.originalFormat == kKeePass1];
    [self cell:self.cellViewAttachments setHidden:self.viewModel.database.attachmentPool.count == 0];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    self.cellChangeMasterCredentials.userInteractionEnabled = [self canSetCredentials];
    
    if (@available(iOS 13.0, *)) {
        self.cellChangeMasterCredentials.textLabel.textColor = [self canSetCredentials] ? nil : UIColor.secondaryLabelColor;
    } else {
        self.cellChangeMasterCredentials.textLabel.textColor = [self canSetCredentials] ? nil : UIColor.lightGrayColor;
    }
    
    self.cellChangeMasterCredentials.textLabel.text = self.viewModel.database.originalFormat == kPasswordSafe ?
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
        scVc.initialFormat = self.viewModel.database.originalFormat;
        scVc.initialKeyFileBookmark = self.viewModel.metadata.keyFileBookmark;
        scVc.initialYubiKeyConfig = self.viewModel.metadata.contextAwareYubiKeyConfig;
        
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
    self.onSetMasterCredentials(password, keyFileBookmark, oneTimeKeyFileData, yubiConfig);
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
                                      nodes:self.viewModel.database.allActiveEntries
                                     onDone:^(BOOL go, NSDictionary<NSUUID *,UIImage *> * _Nullable selectedFavIcons) {
        [self dismissViewControllerAnimated:YES completion:nil];
        
        if(go && selectedFavIcons) {
            self.onDatabaseBulkIconUpdate(selectedFavIcons); 
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
