//
//  CredentialProviderViewController.m
//  Strongbox AutoFill
//
//  Created by Mark on 11/10/2018.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import "CredentialProviderViewController.h"
#import "DatabasePreferences.h"
#import "NSArray+Extensions.h"
#import "SafesListTableViewController.h"
#import "Alerts.h"
#import "mach/mach.h"
#import "QuickTypeRecordIdentifier.h"
#import "OTPToken+Generation.h"
#import "Utils.h"
#import "AutoFillManager.h"
#import "AppPreferences.h"
#import "LocalDeviceStorageProvider.h"
#import "ClipboardManager.h"
#import "SyncManager.h"
#import "Model.h"
#import "IOSCompositeKeyDeterminer.h"
#import "DatabaseUnlocker.h"
#import "DuressActionHelper.h"
#import "WorkingCopyManager.h"
#import "SecretStore.h"
#import "NSDate+Extensions.h"

@interface CredentialProviderViewController () <UIAdaptivePresentationControllerDelegate>

@property (nonatomic, strong) UINavigationController* databasesListNavController;
@property (nonatomic, strong) NSArray<ASCredentialServiceIdentifier *> * serviceIdentifiers;

@property BOOL withUserInteraction;
@property ASPasswordCredentialIdentity* credentialIdentity;

@end

@implementation CredentialProviderViewController



- (void)provideCredentialWithoutUserInteractionForIdentity:(ASPasswordCredentialIdentity *)credentialIdentity {
    NSLog(@"provideCredentialWithoutUserInteractionForIdentity: [%@]", credentialIdentity);

    self.credentialIdentity = credentialIdentity;
    self.withUserInteraction = NO;
    
    QuickTypeRecordIdentifier* identifier = [QuickTypeRecordIdentifier fromJson:credentialIdentity.recordIdentifier];
    DatabasePreferences* database = [self getDatabaseFromQuickTypeIdentifier:identifier];

    if ( database ) {
        NSLog(@"provideCredentialWithoutUserInteractionForIdentity - Got DB");
        
        IOSCompositeKeyDeterminer* keyDeterminer = [IOSCompositeKeyDeterminer determinerWithViewController:self
                                                                                                  database:database
                                                                                            isAutoFillOpen:YES
                                                                                   isAutoFillQuickTypeOpen:YES
                                                                                       biometricPreCleared:NO
                                                                                       noConvenienceUnlock:NO];
        if ( keyDeterminer.isAutoFillConvenienceAutoLockPossible ) {
            NSLog(@"provideCredentialWithoutUserInteractionForIdentity - Within Timeout - Filling without UI");
            [self unlockDatabaseForQuickType:database identifier:identifier];
            return;
        }
    }
 
    [self exitWithUserInteractionRequired];
}

- (void)prepareInterfaceToProvideCredentialForIdentity:(ASPasswordCredentialIdentity *)credentialIdentity {
    NSLog(@"prepareInterfaceToProvideCredentialForIdentity = %@", credentialIdentity);
     
    self.credentialIdentity = credentialIdentity;
    self.withUserInteraction = YES;
}

- (void)prepareCredentialListForServiceIdentifiers:(NSArray<ASCredentialServiceIdentifier *> *)serviceIdentifiers {
    NSLog(@"prepareCredentialListForServiceIdentifiers = %@ - nav = [%@]", serviceIdentifiers, self.navigationController);
    
    self.serviceIdentifiers = serviceIdentifiers;
    self.withUserInteraction = YES;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    [self doStartupStuff];
}

- (void)doStartupStuff {
    
    
    BOOL lastRunGood = AppPreferences.sharedInstance.autoFillExitedCleanly && AppPreferences.sharedInstance.autoFillWroteCleanly;

    if(!lastRunGood) {
        [self showLastRunCrashedMessage:^{
            [self startup];
        }];
    }
    else {
        [self startup];
    }
}

- (void)startup {
    if( !self.credentialIdentity ) {
        [self initializeDatabasesListView];
    }
    else {
        [self initializeQuickType];
    }
}

- (void)initializeDatabasesListView {
    [DatabasePreferences reloadIfChangedByOtherComponent];

    UIStoryboard *mainStoryboard = [UIStoryboard storyboardWithName:@"MainInterface" bundle:nil];
    self.databasesListNavController = [mainStoryboard instantiateViewControllerWithIdentifier:@"SafesListNavigationController"];
    self.databasesListNavController.presentationController.delegate = self;
    
    SafesListTableViewController* databasesList = ((SafesListTableViewController*)(self.databasesListNavController.topViewController));
    databasesList.rootViewController = self;

    if(self.presentedViewController) { 
        [self dismissViewControllerAnimated:NO completion:^{
            [self presentViewController:self.databasesListNavController animated:NO completion:nil];
        }];
    }
    else {
        [self presentViewController:self.databasesListNavController animated:NO completion:nil];
    }
}

- (void)initializeQuickType {
    self.withUserInteraction = YES;
    QuickTypeRecordIdentifier* identifier = [QuickTypeRecordIdentifier fromJson:self.credentialIdentity.recordIdentifier];

    NSLog(@"initializeQuickType: [%@] => Found: [%@]", self.credentialIdentity, identifier);

    DatabasePreferences* database = [self getDatabaseFromQuickTypeIdentifier:identifier];

    if (database) {
        [self unlockDatabaseForQuickType:database identifier:identifier];
    }
    else {
        [AutoFillManager.sharedInstance clearAutoFillQuickTypeDatabase];
        
        [Alerts info:self
               title:NSLocalizedString(@"autofill_error_unknown_item_title", @"Strongbox: Error Locating Entry")
             message:NSLocalizedString(@"autofill_error_unknown_item_message", @"Strongbox could not find this entry, it is possibly stale. Strongbox's QuickType AutoFill database has now been cleared, and so you will need to reopen your databases to refresh QuickType AutoFill.")
          completion:^{
            
            [self exitWithErrorOccurred:[Utils createNSError:@"Could not find this record in Strongbox any longer." errorCode:-1]];
        }];
    }
}

- (void)unlockDatabaseForQuickType:(DatabasePreferences*)safe
                        identifier:(QuickTypeRecordIdentifier*)identifier {
    IOSCompositeKeyDeterminer* keyDeterminer = [IOSCompositeKeyDeterminer determinerWithViewController:self database:safe isAutoFillOpen:YES isAutoFillQuickTypeOpen:YES biometricPreCleared:NO noConvenienceUnlock:NO];
    [keyDeterminer getCredentials:^(GetCompositeKeyResult result, CompositeKeyFactors * _Nullable factors, BOOL fromConvenience, NSError * _Nullable error) {
        if (result == kGetCompositeKeyResultSuccess) {
            AppPreferences.sharedInstance.autoFillExitedCleanly = NO; 
            
            DatabaseUnlocker* unlocker = [DatabaseUnlocker unlockerForDatabase:safe viewController:self forceReadOnly:NO isAutoFillOpen:YES offlineMode:YES];
            [unlocker unlockLocalWithKey:factors keyFromConvenience:fromConvenience completion:^(UnlockDatabaseResult result, Model * _Nullable model, NSError * _Nullable innerStreamError, NSError * _Nullable error) {
                AppPreferences.sharedInstance.autoFillExitedCleanly = YES;
                
                [self onUnlockDone:result model:model identifier:identifier error:error];
            }];
        }
        else if (result == kGetCompositeKeyResultError) {
            [self messageErrorAndExit:error];
        }
        else if (result == kGetCompositeKeyResultDuressIndicated) {
            [DuressActionHelper performDuressAction:self database:safe isAutoFillOpen:NO completion:^(UnlockDatabaseResult result, Model * _Nullable model, NSError * _Nullable innerStreamError, NSError * _Nullable error) {
                [self onUnlockDone:result model:model identifier:identifier error:error];
            }];
        }
        else {
            [self cancel:nil];
        }
    }];
}

- (void)onUnlockDone:(UnlockDatabaseResult)result model:(Model * _Nullable)model identifier:(QuickTypeRecordIdentifier*)identifier error:(NSError * _Nullable)error {
    NSLog(@"AutoFill: Open Database: Model=[%@] - Error = [%@]", model, error);
    
    if(result == kUnlockDatabaseResultSuccess) {
        [self onUnlockedDatabase:model quickTypeIdentifier:identifier];
    }
    else if(result == kUnlockDatabaseResultUserCancelled || result == kUnlockDatabaseResultViewDebugSyncLogRequested) {
        [self cancel:nil]; 
    }
    else if (result == kUnlockDatabaseResultIncorrectCredentials) {
        
        NSLog(@"INCORRECT CREDENTIALS - kUnlockDatabaseResultIncorrectCredentials");
        [self exitWithErrorOccurred:error ? error : [Utils createNSError:@"Could not open database" errorCode:-1]];
    }
    else if (result == kUnlockDatabaseResultError) {
        [self messageErrorAndExit:error];
    }
}
 
- (void)onUnlockedDatabase:(Model*)model quickTypeIdentifier:(QuickTypeRecordIdentifier*)identifier {
    if (model.metadata.autoFillConvenienceAutoUnlockTimeout == -1 && self.withUserInteraction ) {
        [self onboardForAutoFillConvenienceAutoUnlock:self database:model.metadata completion:^{
            [self continueUnlockedDatabase:model quickTypeIdentifier:identifier];
        }];
    }
    else {
        [self continueUnlockedDatabase:model quickTypeIdentifier:identifier];
    }
}

- (void)continueUnlockedDatabase:(Model*)model quickTypeIdentifier:(QuickTypeRecordIdentifier*)identifier {
    if ( model.metadata.autoFillConvenienceAutoUnlockTimeout > 0 ) {
        model.metadata.autoFillConvenienceAutoUnlockPassword = model.database.ckfs.password;
        [self markLastUnlockedAtTime:model.metadata];
    }
    
    NSUUID *uuid = [[NSUUID alloc] initWithUUIDString:identifier.nodeId];
    
    Node* node = [model.database getItemById:uuid];
    
    if ( node ) {
        [self exitWithCredential:model item:node quickTypeIdentifier:identifier];
    }
    else {
        [AutoFillManager.sharedInstance clearAutoFillQuickTypeDatabase];
        
        [Alerts info:self title:@"Strongbox: Error Locating This Record"
             message:@"Strongbox could not find this record in the database any longer. It is possibly stale. Strongbox's QuickType AutoFill database has now been cleared, and so you will need to reopen your databases to refresh QuickType AutoFill."
          completion:^{
            [self exitWithErrorOccurred:[Utils createNSError:@"Could not find record in database" errorCode:-1]];
        }];
    }
}

- (void)messageErrorAndExit:(NSError*)error {
    [Alerts error:self
            title:NSLocalizedString(@"open_sequence_problem_opening_title", @"There was a problem opening the database.")
            error:error
       completion:^{
        [self exitWithErrorOccurred:error ? error : [Utils createNSError:@"Could not open database" errorCode:-1]];
    }];
}

- (void)presentationControllerDidDismiss:(UIPresentationController *)presentationController {

    [self cancel:nil];
}

- (BOOL)autoFillIsPossibleWithSafe:(DatabasePreferences*)safeMetaData {
    if(!safeMetaData.autoFillEnabled) {
        return NO;
    }
        
    return [WorkingCopyManager.sharedInstance isLocalWorkingCacheAvailable:safeMetaData.uuid modified:nil];
}

- (NSArray<ASCredentialServiceIdentifier *> *)getCredentialServiceIdentifiers {
    return self.serviceIdentifiers;
}

- (IBAction)cancel:(id)sender {
    [self exitWithUserCancelled:nil];
}




- (void)showLastRunCrashedMessage:(void (^)(void))completion {
    NSLog(@"Exit Clean = %hhd, Wrote Clean = %hhd", AppPreferences.sharedInstance.autoFillExitedCleanly, AppPreferences.sharedInstance.autoFillWroteCleanly);
    
    NSString* title = NSLocalizedString(@"autofill_did_not_close_cleanly_title", @"AutoFill Crash Occurred");
    NSString* message = NSLocalizedString(@"autofill_did_not_close_cleanly_message", @"It looks like the last time you used AutoFill you had a crash. This is usually due to a memory limitation. Please check your database file size and your Argon2 memory settings (should be <= 64MB).");

    [Alerts info:self title:title message:message completion:completion];

    
    
    AppPreferences.sharedInstance.autoFillExitedCleanly = YES;
    AppPreferences.sharedInstance.autoFillWroteCleanly = YES;
}

- (void)exitWithUserCancelled:(DatabasePreferences*)unlockedDatabase {
    NSLog(@"EXIT: User Cancelled");
    AppPreferences.sharedInstance.autoFillExitedCleanly = YES;
    
    if ( unlockedDatabase ) {
        [self markLastUnlockedAtTime:unlockedDatabase];
    }
    
    [self.extensionContext cancelRequestWithError:[NSError errorWithDomain:ASExtensionErrorDomain code:ASExtensionErrorCodeUserCanceled userInfo:nil]];
}

- (void)exitWithUserInteractionRequired {
    NSLog(@"EXIT: User Interaction Required");
    [self.extensionContext cancelRequestWithError:[NSError errorWithDomain:ASExtensionErrorDomain
                                                                      code:ASExtensionErrorCodeUserInteractionRequired
                                                                  userInfo:nil]];
}

- (void)exitWithErrorOccurred:(NSError*)error {
    NSLog(@"EXIT: Error Occured [%@]", error);
    AppPreferences.sharedInstance.autoFillExitedCleanly = YES; 
    
    [self.extensionContext cancelRequestWithError:error];
}

- (void)exitWithCredential:(Model*)model item:(Node*)item {
    [self exitWithCredential:model item:item quickTypeIdentifier:nil];
}

- (void)exitWithCredential:(Model*)model item:(Node*)item quickTypeIdentifier:(QuickTypeRecordIdentifier*)quickTypeIdentifier {
    NSString* user = [model.database dereference:item.fields.username node:item];
    
    NSString* password = @"";

    if ( quickTypeIdentifier && quickTypeIdentifier.fieldKey ) {
        StringValue* sv = item.fields.customFields[quickTypeIdentifier.fieldKey];
        if ( sv ) {
            password = sv.value;
        }
    }
    else {
        password = [model.database dereference:item.fields.password node:item];
    }
    
    password = password ? password : @"";

    
    
    NSString* totp = item.fields.otpToken ? item.fields.otpToken.password : @"";
    if ( totp.length && model.metadata.autoFillCopyTotp ) {
        [ClipboardManager.sharedInstance copyStringWithDefaultExpiration:totp];
        NSLog(@"Copied TOTP to Pasteboard... %hhd", self.withUserInteraction);
        
        if ( AppPreferences.sharedInstance.showAutoFillTotpCopiedMessage && self.withUserInteraction ) {
            [Alerts twoOptions:self
                         title:NSLocalizedString(@"autofill_info_totp_copied_title", @"TOTP Copied")
                       message:NSLocalizedString(@"autofill_info_totp_copied_message", @"Your TOTP Code has been copied to the clipboard.")
             defaultButtonText:NSLocalizedString(@"autofill_add_entry_sync_required_option_got_it", @"Got it!")
              secondButtonText:NSLocalizedString(@"autofill_add_entry_sync_required_option_dont_tell_again", @"Don't tell me again")
                        action:^(BOOL response) {
                if ( !response ) { 

                    AppPreferences.sharedInstance.showAutoFillTotpCopiedMessage = NO;
                }
                
                [self exitWithCredential:model.metadata user:user password:password];
            }];
        }
        else {
            [self exitWithCredential:model.metadata user:user password:password];
        }
    }
    else {
        [self exitWithCredential:model.metadata user:user password:password];
    }
}

- (void)exitWithCredential:(DatabasePreferences*)database user:(NSString*)user password:(NSString*)password {
    NSLog(@"EXIT: Success");
 
    AppPreferences.sharedInstance.autoFillExitedCleanly = YES;
    
    [self markLastUnlockedAtTime:database];
    
    ASPasswordCredential *credential = [[ASPasswordCredential alloc] initWithUser:user password:password];
    [self.extensionContext completeRequestWithSelectedCredential:credential completionHandler:nil];
}

- (void)markLastUnlockedAtTime:(DatabasePreferences*)database {
    database.autoFillLastUnlockedAt = NSDate.date;
}

- (void)onboardForAutoFillConvenienceAutoUnlock:(UIViewController *)viewController database:(DatabasePreferences *)database completion:(void (^)(void))completion {
    if ( !self.presentedViewController ) { 
        [Alerts threeOptions:viewController
                       title:NSLocalizedString(@"autofill_auto_unlock_title", @"Auto Unlock Feature")
                     message:NSLocalizedString(@"autofill_auto_unlock_message", @"Auto Unlock lets you avoid repeatedly unlocking your database in AutoFill mode within a configurable time window. Would you like to use this handy feature?\n\nNB: Your password is stored in the Secure Enclave for this feature.")
           defaultButtonText:NSLocalizedString(@"autofill_auto_unlock_try_3_minutes", @"Great, lets try 3 mins")
            secondButtonText:NSLocalizedString(@"autofill_auto_unlock_try_10_minutes", @"I'd prefer 10 mins")
             thirdButtonText:NSLocalizedString(@"mac_upgrade_no_thanks", @"No Thanks")
                                action:^(int response) {
            if (response == 0) {
                database.autoFillConvenienceAutoUnlockTimeout = 180;
            }
            else if (response == 1) {
                database.autoFillConvenienceAutoUnlockTimeout = 600;
            }
            else if (response == 2) {
                database.autoFillConvenienceAutoUnlockTimeout = 0;
            }
            
            completion();
        }];
    }
    else {
        completion();
    }
}

- (DatabasePreferences*)getDatabaseFromQuickTypeIdentifier:(QuickTypeRecordIdentifier*)identifier {
    return identifier ? [DatabasePreferences fromUuid:identifier.databaseId] : nil;
}

@end
