//
//  BrowseActionsHelper.m
//  Strongbox
//
//  Created by Strongbox on 29/07/2024.
//  Copyright © 2024 Mark McGuill. All rights reserved.
//

#import "BrowseActionsHelper.h"
#import "ClipboardManager.h"
#import "Model.h"
#import "SBLog.h"
#import "OTPToken+Generation.h"
#import "LargeTextViewController.h"
#import "AuditDrillDownController.h"
#import "Utils.h"
#import "NSArray+Extensions.h"
#import "Alerts.h"
#import "KeyFileManagement.h"
#import "YubiManager.h"
#import "CASGTableViewController.h"
#import "ExportHelper.h"

#ifndef IS_APP_EXTENSION
#import <ISMessages/ISMessages.h>
#endif

#ifndef IS_APP_EXTENSION
#import "Strongbox-Swift.h"
#else
#import "Strongbox_Auto_Fill-Swift.h"
#endif

@interface BrowseActionsHelper ()

@property Model* model;
@property (weak) UIViewController* viewController;
@property (nonatomic, copy) void (^updateDatabase)(BOOL, void(^ _Nullable )(BOOL));

@end

@implementation BrowseActionsHelper

- (instancetype)initWithModel:(Model *)model 
               viewController:(UIViewController *)viewController
         updateDatabaseAction:(void (^)(BOOL, void (^ _Nullable)(BOOL)))updateDatabaseAction {
    self = [super init];
    if (self) {
        self.model = model;
        self.viewController = viewController;
        self.updateDatabase = updateDatabaseAction;
    }
    return self;
}

- (void)showPassword:(NSUUID*)uuid {
    Node* item = [self.model getItemById:uuid];
    
    if ( !item ) {
        slog(@"🔴 BrowseActionsHelper - Could not find item to copy password");
        return;
    }
    
    NSString* password = [self dereference:item.fields.password node:item];
    
    LargeTextViewController* vc = [LargeTextViewController fromStoryboard];
    vc.string = password;
    vc.colorize = self.model.metadata.colorizePasswords;
    
    [self.viewController presentViewController:vc animated:YES completion:nil];
}

#ifndef IS_APP_EXTENSION

- (void)showAuditDrillDown:(NSUUID*)uuid {
    UINavigationController* nav = [AuditDrillDownController fromStoryboard];
    AuditDrillDownController *vc = (AuditDrillDownController*)nav.topViewController;
    
    vc.model = self.model;
    vc.itemId = uuid;
    
    __weak BrowseActionsHelper* weakSelf = self;
    
    vc.updateDatabase = ^{
        weakSelf.updateDatabase(NO, nil);
    };
    
    [self.viewController presentViewController:nav animated:YES completion:nil];
}

- (void)showHardwareKeySettings  {
    __weak BrowseActionsHelper* weakSelf = self;
    
    UIViewController* vc = [SwiftUIViewFactory getHardwareKeySettingsViewWithMetadata:self.model.metadata onSettingsChanged:^(BOOL hardwareKeyCRCaching, NSInteger cacheChallengeDurationSecs, NSInteger challengeRefreshIntervalSecs, BOOL autoFillRefreshSuppressed) {
        weakSelf.model.metadata.hardwareKeyCRCaching = hardwareKeyCRCaching;
        weakSelf.model.metadata.cacheChallengeDurationSecs = cacheChallengeDurationSecs;
        weakSelf.model.metadata.challengeRefreshIntervalSecs = challengeRefreshIntervalSecs;
        weakSelf.model.metadata.doNotRefreshChallengeInAF = autoFillRefreshSuppressed;
        
        if ( hardwareKeyCRCaching ) {
            if ( weakSelf.model.ckfs.lastChallengeResponse ) {
                [weakSelf.model.metadata addCachedChallengeResponse:weakSelf.model.ckfs.lastChallengeResponse];
            }
            weakSelf.model.metadata.lastChallengeRefreshAt = NSDate.now;
        }
        else {
            [weakSelf.model.metadata clearCachedChallengeResponses];
            weakSelf.model.metadata.lastChallengeRefreshAt = nil;
        }
    } completion:^{
        [weakSelf.viewController dismissViewControllerAnimated:YES completion:nil];
    }];
    
    UINavigationController* nav = [[UINavigationController alloc] initWithRootViewController:vc];
    nav.modalPresentationStyle = UIModalPresentationFormSheet;
    
    [self.viewController presentViewController:nav animated:YES completion:nil];
}

#endif



- (void)copyPassword:(NSUUID *)uuid {
    Node* item = [self.model getItemById:uuid];
    
    if ( !item ) {
        slog(@"🔴 BrowseActionsHelper - Could not find item to copy password");
        return;
    }
    
    BOOL copyTotp = (item.fields.password.length == 0 && item.fields.otpToken);
    
    [ClipboardManager.sharedInstance copyStringWithDefaultExpiration:copyTotp ? item.fields.otpToken.password : [self dereference:item.fields.password node:item]];
    
    NSString* message = [NSString stringWithFormat:copyTotp ?
                         NSLocalizedString(@"browse_vc_totp_copied_fmt", @"'%@' OTP Code Copied") :
                         NSLocalizedString(@"browse_vc_password_copied_fmt", @"'%@' Password Copied"),
                         [self dereference:item.title node:item]];
    
    [self showToast:message];
}

- (void)copyAllFields:(NSUUID*)uuid {
    NSString* allString = [self.model getAllFieldsKeyValuesString:uuid];
    
    [ClipboardManager.sharedInstance copyStringWithDefaultExpiration:allString];
    
    [self showToast:NSLocalizedString(@"generic_copied", @"Copied")];
}

- (void)copyUsername:(NSUUID*)uuid {
    Node* item = [self.model getItemById:uuid];
    
    if ( !item ) {
        slog(@"🔴 BrowseActionsHelper - Could not find item to copy password");
        return;
    }
    
    [ClipboardManager.sharedInstance copyStringWithDefaultExpiration:[self dereference:item.fields.username node:item]];
    
    [self showToast:[NSString stringWithFormat:NSLocalizedString(@"browse_vc_username_copied_fmt", @"'%@' Username Copied"), [self dereference:item.title node:item]]];
}

- (void)copyTotp:(NSUUID*)uuid {
    Node* item = [self.model getItemById:uuid];
    
    if ( !item ) {
        slog(@"🔴 BrowseActionsHelper - Could not find item to copy password");
        return;
    }
    
    if(!item.fields.otpToken) {
        [self showToast:[NSString stringWithFormat:NSLocalizedString(@"browse_vc_no_totp_to_copy_fmt", @"'%@': No TOTP setup to Copy!"),
                         [self dereference:item.title node:item]]];
        return;
    }
    
    [ClipboardManager.sharedInstance copyStringWithDefaultExpiration:item.fields.otpToken.password];
    
    [self showToast:[NSString stringWithFormat:NSLocalizedString(@"browse_vc_totp_copied_fmt", @"'%@' TOTP Copied"), [self dereference:item.title node:item]]];
}

- (void)copyUrl:(NSUUID*)uuid {
    Node* item = [self.model getItemById:uuid];
    
    if ( !item ) {
        slog(@"🔴 BrowseActionsHelper - Could not find item to copy password");
        return;
    }
    
    [ClipboardManager.sharedInstance copyStringWithDefaultExpiration:[self dereference:item.fields.url node:item]];
    
    [self showToast:[NSString stringWithFormat:NSLocalizedString(@"browse_vc_url_copied_fmt", @"'%@' URL Copied"), [self dereference:item.title node:item]]];
}

- (void)copyEmail:(NSUUID*)uuid {
    Node* item = [self.model getItemById:uuid];
    
    if ( !item ) {
        slog(@"🔴 BrowseActionsHelper - Could not find item to copy password");
        return;
    }
    
    [ClipboardManager.sharedInstance copyStringWithDefaultExpiration:[self dereference:item.fields.email node:item]];
    
    [self showToast:[NSString stringWithFormat:NSLocalizedString(@"browse_vc_email_copied_fmt", @"'%@' Email Copied"), [self dereference:item.title node:item]]];
}

- (void)copyNotes:(NSUUID*)uuid {
    Node* item = [self.model getItemById:uuid];
    
    if ( !item ) {
        slog(@"🔴 BrowseActionsHelper - Could not find item to copy password");
        return;
    }
    
    [ClipboardManager.sharedInstance copyStringWithDefaultExpiration:[self dereference:item.fields.notes node:item]];
    
    [self showToast:[NSString stringWithFormat:NSLocalizedString(@"browse_vc_notes_copied_fmt", @"'%@' Notes Copied"), [self dereference:item.title node:item]]];
}

- (void)copyAndLaunch:(NSUUID*)uuid {
    Node* item = [self.model getItemById:uuid];
    
    if ( !item ) {
        slog(@"🔴 BrowseActionsHelper - Could not find item to copy password");
        return;
    }
    
    if ( item.fields.url.length ) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, .25 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
            [self copyPassword:item.uuid];
            [self.model launchUrl:item];
        });
    }
}

- (void)copyCustomField:(NSString*)key uuid:(NSUUID*)uuid {
    Node* item = [self.model getItemById:uuid];
    
    if ( !item ) {
        slog(@"🔴 BrowseActionsHelper - Could not find item to copy password");
        return;
    }
    
    StringValue* sv = item.fields.customFields[key];
    
    NSString* value = [self dereference:sv.value node:item];
    
    [ClipboardManager.sharedInstance copyStringWithDefaultExpiration:value];
    
    [self showToast:[NSString stringWithFormat:NSLocalizedString(@"item_details_something_copied_fmt", @"'%@' Copied"), key]];
}



- (void)deleteSingleItem:(NSUUID * _Nonnull)uuid 
              completion:(void (^)(BOOL actionPerformed))completion {
    Node* item = [self.model getItemById:uuid];

    if ( !item ) {
        slog(@"🔴 Could not find item to delete!"); 
        if ( completion ) {
            completion(NO);
        }
        return;
    }
    
    BOOL willRecycle = [self.model canRecycle:item.uuid];
    
    [Alerts yesNo:self.viewController 
            title:NSLocalizedString(@"browse_vc_are_you_sure", @"Are you sure?")
          message:[NSString stringWithFormat:willRecycle ?
                   NSLocalizedString(@"browse_vc_are_you_sure_recycle_fmt", @"Are you sure you want to send '%@' to the Recycle Bin?") :
                   NSLocalizedString(@"browse_vc_are_you_sure_delete_fmt", @"Are you sure you want to permanently delete '%@'?"), [self dereference:item.title node:item]]
           action:^(BOOL response) {
        if (response) {
            BOOL failed = NO;
            if (willRecycle) {
                failed = ![self.model recycleItems:@[item]];
            }
            else {
                [self.model deleteItems:@[item]];
            }
            
            if (failed) {
                [Alerts warn:self.viewController
                       title:NSLocalizedString(@"browse_vc_delete_failed", @"Delete Failed")
                     message:NSLocalizedString(@"browse_vc_delete_error_message", @"There was an error trying to delete this item.")];
            }
            else {
                self.updateDatabase(YES, nil);
            }
        }
        
        if (completion) {
            completion(response);
        }
    }];
}

- (void)emptyRecycleBin:(void (^)(BOOL actionPerformed))completion {
    [Alerts areYouSure:self.viewController
               message:NSLocalizedString(@"browse_vc_action_empty_recycle_bin_are_you_sure", @"This will permanently delete all items contained within the Recycle Bin.") action:^(BOOL response) {
        if ( response ) {
            [self.model emptyRecycleBin];
            
            self.updateDatabase(NO,nil);
        }
        
        if(completion) {
            completion(response);
        }
    }];
}



- (void)presentSetCredentials {
    CASGTableViewController* scVc = [CASGTableViewController instantiateFromStoryboard];
    UINavigationController* nav = scVc.navigationController;
    
    scVc.mode = kCASGModeSetCredentials;
    scVc.initialFormat = self.model.database.originalFormat;
    scVc.initialKeyFileBookmark = self.model.metadata.keyFileBookmark;
    scVc.initialYubiKeyConfig = self.model.metadata.contextAwareYubiKeyConfig;
    
    __weak BrowseActionsHelper* weakSelf = self;
    scVc.onDone = ^(BOOL success, CASGParams * _Nullable creds) {
        [weakSelf.viewController dismissViewControllerAnimated:YES completion:^{
            if(success) {
                [self setCredentials:creds.password
                     keyFileBookmark:creds.keyFileBookmark
                     keyFileFileName:creds.keyFileFileName
                  oneTimeKeyFileData:creds.oneTimeKeyFileData
                          yubiConfig:creds.yubiKeyConfig];
            }
        }];
    };
    
    [self.viewController presentViewController:nav animated:YES completion:nil];
}

- (void)setCredentials:(NSString*)password
       keyFileBookmark:(NSString*)keyFileBookmark
       keyFileFileName:(NSString*)keyFileFileName
    oneTimeKeyFileData:(NSData*)oneTimeKeyFileData
            yubiConfig:(YubiKeyHardwareConfiguration*)yubiConfig {
    CompositeKeyFactors *newCkf = [[CompositeKeyFactors alloc] initWithPassword:password];
    
    BOOL usingImportedKeyFile = keyFileBookmark || keyFileFileName;
    BOOL keyFileInvolved = usingImportedKeyFile || oneTimeKeyFileData;
    
    if( keyFileInvolved ) {
        NSError* error;
        NSData* keyFileDigest = [KeyFileManagement getDigestFromSources:keyFileBookmark
                                                        keyFileFileName:keyFileFileName
                                                     onceOffKeyFileData:oneTimeKeyFileData
                                                                 format:self.model.database.originalFormat
                                                                  error:&error];
        
        if ( keyFileDigest == nil ) {
            [Alerts error:self.viewController
                    title:NSLocalizedString(@"db_management_error_title_couldnt_change_credentials", @"Could not change credentials")
                    error:error];
            return;
        }
        
        newCkf = [CompositeKeyFactors password:newCkf.password keyFileDigest:keyFileDigest];
    }
    
    if (yubiConfig && yubiConfig.mode != kNoYubiKey) {
        newCkf = [CompositeKeyFactors password:newCkf.password keyFileDigest:newCkf.keyFileDigest yubiKeyCR:^(NSData * _Nonnull challenge, YubiKeyCRResponseBlock  _Nonnull completion) {
            [YubiManager.sharedInstance getResponse:yubiConfig challenge:challenge completion:completion];
        }];
    }
    
    CompositeKeyFactors *rollbackCkf = [self.model.database.ckfs clone];
    self.model.database.ckfs = newCkf;
    
    __weak BrowseActionsHelper* weakSelf = self;
    
    self.updateDatabase(NO, ^(BOOL savedWorkingCopy) {
        if ( savedWorkingCopy ) {
            [weakSelf onSuccessfulCredentialsChanged:keyFileBookmark
                                 keyFileFileName:keyFileFileName
                              oneTimeKeyFileData:oneTimeKeyFileData
                                      yubiConfig:yubiConfig];
        }
        else { 
            weakSelf.model.database.ckfs = rollbackCkf;
        }
    });
}

- (void)onSuccessfulCredentialsChanged:(NSString*)keyFileBookmark
                       keyFileFileName:(NSString*)keyFileFileName
                    oneTimeKeyFileData:(NSData*)oneTimeKeyFileData
                            yubiConfig:(YubiKeyHardwareConfiguration*)yubiConfig {
    if ( self.model.metadata.isConvenienceUnlockEnabled ) {
        if(!oneTimeKeyFileData) {
            self.model.metadata.convenienceMasterPassword = self.model.database.ckfs.password;
            self.model.metadata.conveniencePasswordHasBeenStored = YES;
            slog(@"Keychain updated on Master password changed for touch id enabled and enrolled safe.");
        }
        else {
            
            self.model.metadata.convenienceMasterPassword = nil;
            self.model.metadata.autoFillConvenienceAutoUnlockPassword = nil;
            self.model.metadata.conveniencePasswordHasBeenStored = NO;
        }
    }
    
    [self.model.metadata setKeyFile:keyFileBookmark keyFileFileName:keyFileFileName];
    self.model.metadata.nextGenPrimaryYubiKeyConfig = yubiConfig;

    __weak BrowseActionsHelper* weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        NSString* message = weakSelf.model.database.originalFormat == kPasswordSafe ?
        NSLocalizedString(@"db_management_password_changed", @"Master Password Changed") :
        NSLocalizedString(@"db_management_credentials_changed", @"Master Credentials Changed");
        
        [weakSelf showToast:message];
    });
}



- (NSString*)dereference:(NSString*)text node:(Node*)node {
    return [self.model.database dereference:text node:node];
}

- (void)showToast:(NSString*)message {
#ifndef IS_APP_EXTENSION
    [ISMessages showCardAlertWithTitle:message
                               message:nil
                              duration:3.f
                           hideOnSwipe:YES
                             hideOnTap:YES
                             alertType:ISAlertTypeSuccess
                         alertPosition:ISAlertPositionTop
                               didHide:nil];
#endif
}

- (void)onDatabaseBulkIconUpdate:(NSDictionary<NSUUID *,NodeIcon *> *)selectedFavIcons {
    BOOL change = NO;
    for(Node* node in self.model.database.allActiveEntries) {
        NodeIcon* icon = selectedFavIcons[node.uuid];
        if( icon ) {
            node.icon = icon;
            change = YES;
        }
    }
    
    if ( change ) {
        self.updateDatabase(NO, nil);
    }
}

- (void)printDatabase {
    NSString* htmlString = [self.model.database getHtmlPrintString:self.model.metadata.nickName];
    
    UIMarkupTextPrintFormatter *formatter = [[UIMarkupTextPrintFormatter alloc] initWithMarkupText:htmlString];
    
    UIPrintInteractionController.sharedPrintController.printFormatter = formatter;
    
    [UIPrintInteractionController.sharedPrintController presentAnimated:YES completionHandler:nil];
}

- (void)exportDatabase {
    DatabasePreferences* database = self.model.metadata;
    NSError* error;
    NSURL* url = [ExportHelper getExportFile:database error:&error];
    if ( !url || error ) {
        [Alerts error:self.viewController error:error];
        return;
    }
    
    NSArray *activityItems = @[url];
    UIActivityViewController *activityViewController = [[UIActivityViewController alloc] initWithActivityItems:activityItems applicationActivities:nil];
        
    UIView* view = self.viewController.view;
    activityViewController.popoverPresentationController.sourceView = view;
    activityViewController.popoverPresentationController.sourceRect = CGRectMake(CGRectGetMidX(view.bounds), CGRectGetMidY(view.bounds),0,0);
    activityViewController.popoverPresentationController.permittedArrowDirections = 0L; 
    
    [activityViewController setCompletionWithItemsHandler:^(NSString *activityType, BOOL completed, NSArray *returnedItems, NSError *activityError) {
        [ExportHelper cleanupExportFiles:url];
    }];
    
    [self.viewController presentViewController:activityViewController animated:YES completion:nil];
}

@end
