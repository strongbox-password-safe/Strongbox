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
#import "AppPreferences.h"
#import "DatabaseFormatIncompatibilityHelper.h"
#import "DatabasePreferences.h"
#import "DatabaseUnlocker.h"
#import "ExportItemsOptionsViewController.h"
#import "IOSCompositeKeyDeterminer.h"
#import "SelectDatabaseViewController.h"
#import "SelectDestinationGroupController.h"
#import "SVProgressHUD.h"

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
                                                            fallbackUrl:nil
                                                        keyFileFileName:keyFileFileName
                                                     onceOffKeyFileData:oneTimeKeyFileData
                                                                 format:self.model.database.originalFormat
                                                     resolvedKeyFileUrl:nil
                                                        updatedBookmark:nil
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
    [StrongboxToastMessages showSlimWithTitle:message];
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

    [ExportHelper getExportFile:self.viewController database:database completion:^(NSURL * _Nullable url, NSError * _Nullable error) {
        if ( url == nil && error == nil ) {
            return; 
        }

        if ( !url || error ) {
            [Alerts error:self.viewController error:error];
        }
        else {
            [self onGotExportFile:url];
        }
    }];
}

- (void)onGotExportFile:(NSURL*)url {
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

- (BOOL)canExportItems {
    BOOL moreThanOneDb = [DatabasePreferences filteredDatabases:^BOOL(DatabasePreferences * _Nonnull obj) {
        return ![obj.uuid isEqualToString:self.model.metadata.uuid] && !obj.readOnly;
    }].count > 0;

    return !AppPreferences.sharedInstance.disableExport && moreThanOneDb;
}

- (NSArray<Node*>*)nodesForUuids:(NSArray<NSUUID*>*)uuids {
    NSMutableArray<Node*>* nodes = NSMutableArray.array;

    for (NSUUID* uuid in uuids) {
        Node* node = [self.model getItemById:uuid];
        if ( node ) {
            [nodes addObject:node];
        }
    }

    return nodes;
}

- (void)moveItems:(NSArray<NSUUID*>*)uuids completion:(void (^)(BOOL actionPerformed))completion {
    NSArray<Node*>* itemsToMove = [self nodesForUuids:uuids];
    if ( itemsToMove.count == 0 ) {
        completion(NO);
        return;
    }

    SelectDestinationGroupController* vc = [[SelectDestinationGroupController alloc] initWithStyle:UITableViewStylePlain];
    vc.currentGroup = self.model.database.effectiveRootGroup;
    vc.viewModel = self.model;

    __weak BrowseActionsHelper* weakSelf = self;
    vc.validateDestination = ^BOOL(Node * _Nonnull destinationGroup) {
        return [weakSelf.model.database validateMoveItems:itemsToMove destination:destinationGroup];
    };

    vc.onSelectedDestination = ^(Node * _Nonnull destination) {
        [weakSelf moveItems:itemsToMove destination:destination];
    };

    UINavigationController* nav = [[UINavigationController alloc] initWithRootViewController:vc];
    nav.modalPresentationStyle = UIModalPresentationFormSheet;
    nav.toolbarHidden = NO;

    [self.viewController presentViewController:nav animated:YES completion:^{
        completion(YES);
    }];
}

- (void)moveItems:(NSArray<Node*>*)items destination:(Node*)destination {
    BOOL ret = [self.model moveItems:items destination:destination];

    if (!ret) {
        NSError* error = [Utils createNSError:NSLocalizedString(@"moveentry_vc_error_moving", @"Error Moving") errorCode:-1];
        [Alerts error:self.viewController error:error];
        return;
    }

    self.updateDatabase(YES, nil);
}

- (void)exportItems:(NSArray<NSUUID*>*)uuids completion:(void (^)(BOOL actionPerformed))completion {
    NSArray<Node*>* items = [self nodesForUuids:uuids];
    NSSet* minimalNodeSet = [self.model.database getMinimalNodeSet:items];

    if ( minimalNodeSet.count == 0 || !self.canExportItems ) {
        completion(NO);
        return;
    }

    [self beginExportItemsSequence:minimalNodeSet.allObjects];
    completion(YES);
}

- (void)beginExportItemsSequence:(NSArray<Node*>*)itemsToExport {
    UINavigationController* nav = [SelectDatabaseViewController fromStoryboard];
    SelectDatabaseViewController* vc = (SelectDatabaseViewController*)nav.topViewController;
    vc.disableDatabaseUuid = self.model.metadata.uuid;
    vc.disableReadOnlyDatabases = YES;
    vc.customTitle = NSLocalizedString(@"export_items_select_destination_database_title", @"Destination Database");

    __weak BrowseActionsHelper* weakSelf = self;
    vc.onSelectedDatabase = ^(DatabasePreferences * _Nullable secondDatabase, UIViewController *__weak  _Nonnull vcToDismiss) {
        [vcToDismiss.presentingViewController dismissViewControllerAnimated:YES completion:^{
            if ( secondDatabase ) {
                [weakSelf onExportItemsToDatabase:secondDatabase itemsToExport:itemsToExport];
            }
        }];
    };

    [self.viewController presentViewController:nav animated:YES completion:nil];
}

- (void)onExportItemsToDatabase:(DatabasePreferences*)destinationDatabase
                  itemsToExport:(NSArray<Node*>*)itemsToExport {
    CompositeKeyFactors* firstKey = self.model.database.ckfs;

    [SVProgressHUD showWithStatus:NSLocalizedString(@"generic_loading", @"Loading...")];

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0L), ^{
        Model* expressAttempt = [DatabaseUnlocker expressTryUnlockWithKey:destinationDatabase key:firstKey];
        dispatch_async(dispatch_get_main_queue(), ^{
            [SVProgressHUD dismiss];

            if ( expressAttempt ) {
                [self onExportItemsToDatabaseUnlockDestinationDone:kUnlockDatabaseResultSuccess model:expressAttempt itemsToExport:itemsToExport error:nil];
            }
            else {
                IOSCompositeKeyDeterminer* determiner = [IOSCompositeKeyDeterminer determinerWithViewController:self.viewController
                                                                                                       database:destinationDatabase
                                                                                                 isAutoFillOpen:NO
                                                                     transparentAutoFillBackgroundForBiometrics:NO
                                                                                            biometricPreCleared:NO
                                                                                            noConvenienceUnlock:NO];

                [determiner getCredentials:^(GetCompositeKeyResult result, CompositeKeyFactors * _Nullable factors, BOOL fromConvenience, NSError * _Nullable error) {
                    if (result == kGetCompositeKeyResultSuccess) {
                        DatabaseUnlocker* unlocker = [DatabaseUnlocker unlockerForDatabase:destinationDatabase viewController:self.viewController forceReadOnly:NO isNativeAutoFillAppExtensionOpen:NO offlineMode:YES];
                        [unlocker unlockLocalWithKey:factors keyFromConvenience:fromConvenience completion:^(UnlockDatabaseResult result, Model * _Nullable model, NSError * _Nullable error) {
                            [self onExportItemsToDatabaseUnlockDestinationDone:result model:model itemsToExport:itemsToExport error:error];
                        }];
                    }
                    else if (result == kGetCompositeKeyResultError) {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [Alerts error:self.viewController
                                    title:NSLocalizedString(@"open_sequence_problem_opening_title", @"There was a problem opening the database.")
                                    error:error];
                        });
                    }
                }];
            }
        });
    });
}

- (void)onExportItemsToDatabaseUnlockDestinationDone:(UnlockDatabaseResult)result
                                               model:(Model * _Nullable)destinationModel
                                       itemsToExport:(NSArray<Node*>*)itemsToExport
                                               error:(NSError * _Nullable)error {
    if(result == kUnlockDatabaseResultSuccess) {
        [self onExportItemsToUnlockedDatabase:destinationModel itemsToExport:itemsToExport];
    }
    else if(result == kUnlockDatabaseResultUserCancelled || result == kUnlockDatabaseResultViewDebugSyncLogRequested) {
    }
    else if (result == kUnlockDatabaseResultIncorrectCredentials) {
        slog(@"INCORRECT CREDENTIALS - kUnlockDatabaseResultIncorrectCredentials");
    }
    else if (result == kUnlockDatabaseResultError) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [Alerts error:self.viewController
                    title:NSLocalizedString(@"open_sequence_problem_opening_title", @"There was a problem opening the database.")
                    error:error];
        });
    }
}

- (void)onExportItemsToUnlockedDatabase:(Model * _Nullable)destinationModel
                          itemsToExport:(NSArray<Node*>*)itemsToExport {
    SelectDestinationGroupController* vc = [[SelectDestinationGroupController alloc] initWithStyle:UITableViewStylePlain];
    vc.currentGroup = destinationModel.database.effectiveRootGroup;
    vc.viewModel = destinationModel;
    vc.hideAddGroupButton = YES;
    vc.customSelectDestinationButtonTitle = NSLocalizedString(@"export_items_select_destination_group_title", @"Export Here");

    __weak BrowseActionsHelper* weakSelf = self;
    vc.validateDestination = ^BOOL(Node * _Nonnull destinationGroup) {
        return YES;
    };

    vc.onSelectedDestination = ^(Node * _Nonnull destination) {
        [weakSelf onExportItemsToUnlockedDatabase:destinationModel destinationGroup:destination itemsToExport:itemsToExport];
    };

    UINavigationController* nav = [[UINavigationController alloc] initWithRootViewController:vc];
    nav.modalPresentationStyle = UIModalPresentationFormSheet;
    nav.toolbarHidden = NO;

    [self.viewController presentViewController:nav animated:YES completion:nil];
}

- (void)onExportItemsToUnlockedDatabase:(Model*)destinationModel
                       destinationGroup:(Node*)destinationGroup
                          itemsToExport:(NSArray<Node*>*)itemsToExport {
    NSSet<NSUUID*>* itemsIntersection = [self getSourceDestinationIntersection:itemsToExport destinationModel:destinationModel];

    UIStoryboard* storyboard = [UIStoryboard storyboardWithName:@"ExportItemOptions" bundle:nil];
    UINavigationController* nav = [storyboard instantiateInitialViewController];
    ExportItemsOptionsViewController* vc = (ExportItemsOptionsViewController*)nav.topViewController;

    vc.items = itemsToExport;
    vc.destinationModel = destinationModel;
    vc.itemsIntersection = itemsIntersection;

    __weak BrowseActionsHelper* weakSelf = self;
    vc.completion = ^(BOOL makeBrandNewCopy, BOOL preserveTimestamps) {
        [weakSelf onExportItemsToUnlockedDatabaseContinuation:destinationModel
                                             destinationGroup:destinationGroup
                                                itemsToExport:itemsToExport
                                           makeBrandNewCopies:makeBrandNewCopy
                                           preserveTimestamps:preserveTimestamps];
    };

    [self.viewController presentViewController:nav animated:YES completion:nil];
}

- (void)onExportItemsToUnlockedDatabaseContinuation:(Model*)destinationModel
                                   destinationGroup:(Node*)destinationGroup
                                      itemsToExport:(NSArray<Node*>*)itemsToExport
                                 makeBrandNewCopies:(BOOL)makeBrandNewCopies
                                 preserveTimestamps:(BOOL)preserveTimestamps {
    NSMutableArray* clonedForExport = NSMutableArray.array;

    for (Node* exportItem in itemsToExport) {
        Node* clone = [exportItem cloneOrDuplicate:preserveTimestamps
                                         cloneUuid:!makeBrandNewCopies
                                    cloneRecursive:YES
                                          newTitle:nil
                                        parentNode:destinationGroup];

        [clonedForExport addObject:clone];
    }

    BOOL destinationIsRootGroup = (destinationGroup == nil || destinationGroup == destinationModel.database.effectiveRootGroup);

    [DatabaseFormatIncompatibilityHelper processFormatIncompatibilities:clonedForExport
                                                 destinationIsRootGroup:destinationIsRootGroup
                                                           sourceFormat:self.model.database.originalFormat
                                                      destinationFormat:destinationModel.database.originalFormat
                                                    confirmChangesBlock:^(NSString * _Nullable confirmMessage, IncompatibilityConfirmChangesResultBlock resultBlock) {
        [Alerts yesNo:self.viewController
                title:NSLocalizedString(@"database_format_incompatibilities_title", @"Format Incompatibilities")
              message:confirmMessage
               action:^(BOOL response) {
            resultBlock(response);
        }];
    } completion:^(BOOL go, NSArray<Node *> * _Nullable compatibleFilteredNodes) {
        if ( go ) {
            [self continueExportItems:destinationModel
                     destinationGroup:destinationGroup
                        itemsToExport:compatibleFilteredNodes
                   makeBrandNewCopies:makeBrandNewCopies];
        }
    }];
}

- (NSSet<NSUUID*>*)getSourceDestinationIntersection:(NSArray<Node*>*)items destinationModel:(Model*)destinationModel {
    NSMutableArray<Node*> *srcNodes = [items flatMap:^NSArray * _Nonnull(Node * _Nonnull obj, NSUInteger idx) {
        return obj.allChildren;
    }].mutableCopy;
    [srcNodes addObjectsFromArray:items];
    NSSet<NSUUID*>* srcIds = [srcNodes map:^id _Nonnull(Node * _Nonnull obj, NSUInteger idx) {
        return obj.uuid;
    }].set;

    NSArray<Node*>* allItems = destinationModel.database.effectiveRootGroup.allChildren;

    NSSet<NSUUID*>* destIds = [allItems map:^id _Nonnull(Node * _Nonnull obj, NSUInteger idx) {
        return obj.uuid;
    }].set;

    NSMutableSet *intersection = srcIds.mutableCopy;
    [intersection intersectSet:destIds];

    return intersection;
}

- (void)continueExportItems:(Model*)destinationModel
           destinationGroup:(Node*)destinationGroup
              itemsToExport:(NSArray<Node*>*)itemsToExport
         makeBrandNewCopies:(BOOL)makeBrandNewCopies {
    if ( itemsToExport.count == 0 ) {
        slog(@"No items left to export!");
        return;
    }

    NSSet<NSUUID*>* itemsIntersection = [self getSourceDestinationIntersection:itemsToExport destinationModel:destinationModel];

    NSMutableArray<Node*>* existingInDestination = NSMutableArray.array;
    for (NSUUID* existing in itemsIntersection) {
        Node* node = [destinationModel.database getItemById:existing];
        if ( node ) {
            [existingInDestination addObject:node];
        }
    }

    if ( existingInDestination.count ) {
        [destinationModel.database deleteItems:existingInDestination];
    }

    BOOL failOccurred = NO;
    for ( Node* exportItem in itemsToExport ) {
        BOOL added = [destinationModel addChildren:@[exportItem] destination:destinationGroup];

        if ( !added ) {
            slog(@"Failed to exportItem: [%@]", exportItem);
            failOccurred = YES;
        }
        else {
            slog(@"Exported Item: [%@]", exportItem);
        }
    }

    if ( !failOccurred ) {
        [destinationModel asyncUpdateAndSync];

        [Alerts info:self.viewController
               title:NSLocalizedString(@"export_vc_export_successful_title", @"Export Successful")
             message:NSLocalizedString(@"export_vc_export_items_successful_message", @"Your selected items have now be exported to the destination database.")];
    }
    else {
        [Alerts warn:self.viewController
               title:NSLocalizedString(@"export_vc_export_failed_title", @"Export Failed")
             message:NSLocalizedString(@"export_vc_export_items_failed_message", @"There was a problem exporting some or all of these items. The export has been cancelled.")];
    }
}

@end
