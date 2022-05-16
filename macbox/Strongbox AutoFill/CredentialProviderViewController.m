//
//  CredentialProviderViewController.m
//  Strongbox AutoFill
//
//  Created by Mark on 12/11/2020.
//  Copyright © 2020 Mark McGuill. All rights reserved.
//

#import "CredentialProviderViewController.h"
#import "Utils.h"
#import "QuickTypeRecordIdentifier.h"
#import "NSArray+Extensions.h"
#import "AutoFillManager.h"
#import "MacAlerts.h"
#import "Settings.h"
#import "DatabaseModel.h"
#import "BookmarksHelper.h"
#import "OTPToken+Generation.h"
#import "ClipboardManager.h"
#import "BiometricIdHelper.h"
#import <LocalAuthentication/LocalAuthentication.h>
#import "KeyFileParser.h"
#import "ManualCredentialsEntry.h"
#import "SelectDatabaseViewController.h"
#import "SelectCredential.h"
#import "MMWormhole.h"
#import "AutoFillWormhole.h"
#import "SecretStore.h"
#import "Serializator.h"
#import "MacHardwareKeyManager.h"
#import "WorkingCopyManager.h"
#import "NSDate+Extensions.h"
#import "MacUrlSchemes.h"
#import "StrongboxErrorCodes.h"
#import "MacCompositeKeyDeterminer.h"
#import "DatabaseUnlocker.h"

@interface CredentialProviderViewController ()

@property SelectDatabaseViewController* selectDbVc;
@property MMWormhole* wormhole;

@property NSArray<ASCredentialServiceIdentifier *> *serviceIdentifiers;
@property MacDatabasePreferences* database;
@property (nullable) QuickTypeRecordIdentifier* quickTypeIdentifier;

@property BOOL withUserInteraction;
@property BOOL quickTypeMode;

@end

static const CGFloat kWormholeWaitTimeout = 0.35f; 

@implementation CredentialProviderViewController

- (void)exitWithUserCancelled:(MacDatabasePreferences*)unlockedDatabase {
    NSLog(@"EXIT: User Cancelled");
    
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
    [self.extensionContext cancelRequestWithError:error];
}

- (void)exitWithCredential:(MacDatabasePreferences*)unlockedDatabase username:(NSString*)username password:(NSString*)password totp:(NSString*)totp {
    BOOL pro = Settings.sharedInstance.fullVersion || Settings.sharedInstance.freeTrial;
    
    [self markLastUnlockedAtTime:unlockedDatabase];
    
    if (pro) {
        NSLog(@"EXIT: Success");
        
        if ( totp.length) {
            [ClipboardManager.sharedInstance copyConcealedString:totp];
            NSLog(@"Copied TOTP to Pasteboard...");
            
            if ( Settings.sharedInstance.showAutoFillTotpCopiedMessage && self.withUserInteraction ) {
                [MacAlerts twoOptions:NSLocalizedString(@"autofill_info_totp_copied_title", @"TOTP Copied")
                      informativeText:NSLocalizedString(@"autofill_info_totp_copied_message", @"Your TOTP Code has been copied to the clipboard.")
                    option1AndDefault:NSLocalizedString(@"autofill_add_entry_sync_required_option_got_it", @"Got it!")
                              option2:NSLocalizedString(@"autofill_add_entry_sync_required_option_dont_tell_again", @"Don't tell me again")
                               window:self.view.window
                           completion:^(NSUInteger zeroForCancel) {
                    if ( zeroForCancel == 2 ) { 
                        NSLog(@"Don't show again!");
                        Settings.sharedInstance.showAutoFillTotpCopiedMessage = NO;
                    }
                    
                    ASPasswordCredential *credential = [[ASPasswordCredential alloc] initWithUser:username password:password];
                    [self.extensionContext completeRequestWithSelectedCredential:credential completionHandler:nil];
                }];
            }
            else {
                ASPasswordCredential *credential = [[ASPasswordCredential alloc] initWithUser:username password:password];
                [self.extensionContext completeRequestWithSelectedCredential:credential completionHandler:nil];
            }
        }
        else {
            ASPasswordCredential *credential = [[ASPasswordCredential alloc] initWithUser:username password:password];
            [self.extensionContext completeRequestWithSelectedCredential:credential completionHandler:nil];
        }
    }
    else {
        NSLog(@"EXIT: Success but not Pro - Cancelling...");

        if ( self.view && self.view.window && self.withUserInteraction ) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [MacAlerts info:NSLocalizedString(@"mac_autofill_pro_feature_title", @"Pro Feature")
                informativeText:NSLocalizedString(@"mac_autofill_pro_feature_upgrade-message", @"AutoFill is only available on the Pro edition of Strongbox. You can upgrade like this:\n\n1. Launch Strongbox\n2. Click the 'Strongbox' menu\n3. Click 'Upgrade to Pro...'.\n\nThank you!")
                      window:self.view.window
                  completion:^{
                    [self exitWithUserCancelled:unlockedDatabase];
                }];
            });
        }
        else {
            [self exitWithUserCancelled:unlockedDatabase];
        }
    }
}




- (void)provideCredentialWithoutUserInteractionForIdentity:(ASPasswordCredentialIdentity *)credentialIdentity {


    self.quickTypeMode = YES;
    
    BOOL pro = Settings.sharedInstance.fullVersion || Settings.sharedInstance.freeTrial;

    if ( !pro ) {
        [self exitWithUserInteractionRequired];
        return;
    }
    
    QuickTypeRecordIdentifier* identifier = [QuickTypeRecordIdentifier fromJson:credentialIdentity.recordIdentifier];
    NSLog(@"Checking wormhole to see if Main App can provide credentials immediately...");

    if ( identifier ) {
        MacDatabasePreferences* database = [MacDatabasePreferences fromUuid:identifier.databaseId];

        if ( database && database.autoFillEnabled && database.quickWormholeFillEnabled ) {
            [self doQuickWormholeFill:identifier];
            return;
        }
    }
    
    [self exitWithUserInteractionRequired];
}

- (void)doQuickWormholeFill:(QuickTypeRecordIdentifier*)identifier {
    self.wormhole = [[MMWormhole alloc] initWithApplicationGroupIdentifier:Settings.sharedInstance.appGroupName
                                                         optionalDirectory:kAutoFillWormholeName];

    [self.wormhole clearAllMessageContents];
    
    [self.wormhole passMessageObject:@{  @"user-session-id" : NSUserName(), @"id" : [identifier toJson] }
                          identifier:kAutoFillWormholeQuickTypeRequestId];
    
    __block BOOL gotResponse = NO;
    
    NSTimeInterval start = NSDate.timeIntervalSinceReferenceDate;
    
    [self.wormhole listenForMessageWithIdentifier:kAutoFillWormholeQuickTypeResponseId
                                         listener:^(id messageObject) {
        NSTimeInterval interval = NSDate.timeIntervalSinceReferenceDate - start;
        gotResponse = YES;

        NSLog(@"==================================================================================");
        NSLog(@"AUTOFILL-WORMHOLE - Got QuickType Credentials in [%f] seconds", interval);
        NSLog(@"==================================================================================");

        [self.wormhole stopListeningForMessageWithIdentifier:kAutoFillWormholeQuickTypeResponseId];
        [self.wormhole clearAllMessageContents];

        MacDatabasePreferences* metadata = [MacDatabasePreferences fromUuid:identifier.databaseId];
        [self decodeWormholeMessage:messageObject metadata:metadata];
    }];
    
    
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(kWormholeWaitTimeout * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        NSTimeInterval interval = NSDate.timeIntervalSinceReferenceDate - start;

        if (!gotResponse) {
            NSLog(@"==================================================================================");
            NSLog(@"AUTOFILL-WORMHOLE - QuickType Credentials Timeout [%f] seconds", interval);
            NSLog(@"==================================================================================");

            [self.wormhole stopListeningForMessageWithIdentifier:kAutoFillWormholeQuickTypeResponseId];
            [self.wormhole clearAllMessageContents];
            [self exitWithUserInteractionRequired];
        }
    });
}

- (void)decodeWormholeMessage:(id)messageObject metadata:(MacDatabasePreferences*)metadata {
    NSDictionary* message = (NSDictionary*)messageObject;
    NSString* userSession = message[@"user-session-id"];

    if ( [userSession isEqualToString:NSUserName()] ) { 
        NSNumber* success = message[@"success"];
        
        if (!success.boolValue) {
            [self exitWithUserInteractionRequired];
        }
        else {
            NSString* secretStoreId = message[@"secret-store-id"];

            NSDictionary* payload = [SecretStore.sharedInstance getSecureObject:secretStoreId];
            [SecretStore.sharedInstance deleteSecureItem:secretStoreId];
                    
            NSString* username = payload[@"user"];
            NSString* password = payload[@"password"];
            NSString* totp = payload[@"totp"];
            
            [self exitWithCredential:metadata username:username password:password totp:totp];
        }
    }
}




- (void)prepareInterfaceToProvideCredentialForIdentity:(ASPasswordCredentialIdentity *)credentialIdentity {
    NSLog(@"AutoFill: prepareInterfaceToProvideCredentialForIdentity [%@]", credentialIdentity);
    
    self.quickTypeMode = YES;
    self.withUserInteraction = YES;
    
    [self initializeQuickType:credentialIdentity];
}

- (void)initializeQuickType:(ASPasswordCredentialIdentity *)credentialIdentity {
    QuickTypeRecordIdentifier* identifier = [QuickTypeRecordIdentifier fromJson:credentialIdentity.recordIdentifier];

    
    if(identifier) {
        MacDatabasePreferences* safe = [MacDatabasePreferences fromUuid:identifier.databaseId];

        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.15 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            if(safe) {
                [self unlockDatabase:safe quickTypeIdentifier:identifier serviceIdentifiers:nil];
            }
            else {
                [AutoFillManager.sharedInstance clearAutoFillQuickTypeDatabase];

                [MacAlerts info:NSLocalizedString(@"autofill_error_unknown_db_title", @"Strongbox: Unknown Database")
             informativeText:NSLocalizedString(@"autofill_error_unknown_db_message", @"This appears to be a reference to an older Strongbox database which can no longer be found. Strongbox's QuickType AutoFill database has now been cleared, and so you will need to reopen your databases to refresh QuickType AutoFill.")
                      window:self.view.window
                  completion:^{
                    [self exitWithErrorOccurred:[Utils createNSError:@"Could not find this database in Strongbox any longer." errorCode:-1]];
                }];
            }
        });
    }
    else {
        [AutoFillManager.sharedInstance clearAutoFillQuickTypeDatabase];
        
        [MacAlerts info:NSLocalizedString(@"autofill_error_unknown_item_title",@"Strongbox: Error Locating Entry")
     informativeText:NSLocalizedString(@"autofill_error_unknown_item_message",@"Strongbox could not find this entry, it is possibly stale. Strongbox's QuickType AutoFill database has now been cleared, and so you will need to reopen your databases to refresh QuickType AutoFill.")
              window:self.view.window
          completion:^{
            [self exitWithErrorOccurred:[Utils createNSError:@"Could not find this database in Strongbox any longer." errorCode:-1]];
        }];
    }
}




- (void)prepareCredentialListForServiceIdentifiers:(NSArray<ASCredentialServiceIdentifier *> *)serviceIdentifiers {


    __weak CredentialProviderViewController* weakSelf = self;
    self.quickTypeMode = NO;
    self.withUserInteraction = YES;

    self.serviceIdentifiers = serviceIdentifiers;
    
    self.selectDbVc = [SelectDatabaseViewController fromStoryboard];
    self.selectDbVc.autoFillMode = YES;
    
    if ( !self.wormhole ) {
        self.wormhole = [[MMWormhole alloc] initWithApplicationGroupIdentifier:Settings.sharedInstance.appGroupName
                                                             optionalDirectory:kAutoFillWormholeName];
    }
    
    self.selectDbVc.wormhole = self.wormhole;
    
    self.selectDbVc.onDone = ^(BOOL userCancelled, MacDatabasePreferences * _Nonnull database) {
        if (userCancelled) {
            [weakSelf exitWithUserCancelled:nil];
        }
        else {
            [weakSelf unlockDatabase:database quickTypeIdentifier:nil serviceIdentifiers:serviceIdentifiers];
        }
    };
}



- (void)viewWillAppear {
    [super viewWillAppear];

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self presentRequiredUI];
    });
}

- (void)presentRequiredUI {
    if ( !self.quickTypeMode ) {
        NSArray<MacDatabasePreferences*> *databases = [MacDatabasePreferences filteredDatabases:^BOOL(MacDatabasePreferences * _Nonnull database) {
            return database.autoFillEnabled;
        }];

        if ( databases.count == 1 && Settings.sharedInstance.autoFillAutoLaunchSingleDatabase ) {
            NSLog(@"Single Database Launching...");

            MacDatabasePreferences* database = databases.firstObject;
            __weak CredentialProviderViewController* weakSelf = self;

            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [weakSelf unlockDatabase:database quickTypeIdentifier:nil serviceIdentifiers:weakSelf.serviceIdentifiers];
            });
        }
        else {
            [self showDatabases];
        }
    }
    else {
        
        



    }
}

- (void)showDatabases {
    NSLog(@"showDatabases - [%@]", self.selectDbVc);

    if(!self.selectDbVc) {
        [self exitWithErrorOccurred:[Utils createNSError:@"There was an error loading the Safes List View" errorCode:-1]];
    }
    else {
        [self presentViewControllerAsSheet:self.selectDbVc];
    }
}




- (void)unlockDatabase:(MacDatabasePreferences*)database
   quickTypeIdentifier:(QuickTypeRecordIdentifier*_Nullable)quickTypeIdentifier
    serviceIdentifiers:(NSArray<ASCredentialServiceIdentifier *> *)serviceIdentifiers {
    NSLog(@"AUTOFILL: unlockDatabase ENTER");

    if ( !Settings.sharedInstance.isProOrFreeTrial && database.storageProvider != kMacFile ) {
        [MacAlerts info:NSLocalizedString(@"mac_non_file_database_pro_message", @"This database can only be unlocked by Strongbox Pro because it is stored via SFTP or WebDAV.\n\nPlease Upgrade.")
        informativeText:NSLocalizedString(@"mac_non_file_database_pro_message", @"This database can only be unlocked by Strongbox Pro because it is stored via SFTP or WebDAV.\n\nPlease Upgrade.")
                 window:self.view.window
             completion:^{
            [self exitWithUserCancelled:nil];
        }];
        return;
    }
    
    self.database = database;
    self.serviceIdentifiers = serviceIdentifiers;
    self.quickTypeIdentifier = quickTypeIdentifier;
    
    [self tryWormholeConvenienceUnlock];
}

- (void)tryWormholeConvenienceUnlock {
    NSLog(@"AUTOFILL: tryWormholeConvenienceUnlock ENTER");

    if ( !self.wormhole ) {
        self.wormhole = [[MMWormhole alloc] initWithApplicationGroupIdentifier:Settings.sharedInstance.appGroupName
                                                             optionalDirectory:kAutoFillWormholeName];
    }
    
    [self.wormhole clearAllMessageContents];
    
    NSString* requestId = [NSString stringWithFormat:@"%@-%@", kAutoFillWormholeConvUnlockRequestId, self.database.uuid];

    [self.wormhole passMessageObject:@{ @"user-session-id" : NSUserName(),
                                        @"database-id" : self.database.uuid }
                          identifier:requestId];
    
    __block NSString* ret = nil;
    dispatch_group_t group = dispatch_group_create();
    dispatch_group_enter(group);

    NSString* responseId = [NSString stringWithFormat:@"%@-%@", kAutoFillWormholeConvUnlockResponseId, self.database.uuid];
    [self.wormhole listenForMessageWithIdentifier:responseId
                                         listener:^(id messageObject) {

        NSDictionary* dict = messageObject;
        NSString* userSession = dict[@"user-session-id"];

        if ( [userSession isEqualToString:NSUserName()] ) { 
            NSString* secretStoreId = dict[@"secret-store-id"];
            ret = secretStoreId;
            dispatch_group_leave(group);
        }
    }];
        
    NSTimeInterval start = NSDate.timeIntervalSinceReferenceDate;
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0L), ^{
        dispatch_group_wait(group, dispatch_time(DISPATCH_TIME_NOW, kWormholeWaitTimeout * NSEC_PER_SEC));

        NSTimeInterval interval = NSDate.timeIntervalSinceReferenceDate - start;

        NSLog(@"==================================================================================");
        NSLog(@" AUTOFILL-WORMHOLE - Conv Unlock Wait Done: [%@] in [%f] seconds", ret, interval);
        NSLog(@"==================================================================================");

        [self.wormhole stopListeningForMessageWithIdentifier:responseId];
        [self.wormhole clearAllMessageContents];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self unlock:ret];
        });
    });
}

- (void)unlock:(NSString*)maybeWormholeSecurePasswordId {
    BOOL keyFileNotSetButRequired = self.database.keyFileBookmark.length && !self.database.autoFillKeyFileBookmark.length;
    if ( keyFileNotSetButRequired ) {
        NSLog(@"Unlock Database: keyFileNotSetButRequired Showing Manual Unlock to allow user to select...");
        [self manualUnlockDatabase];
        return;
    }

    
    
    NSString* conveniencePassword = nil;
    if ( maybeWormholeSecurePasswordId ) {
        NSLog(@"AUTOFILL: Wormhole convenience unlock found - will unlock database");
        NSString* convUnlock = [SecretStore.sharedInstance getSecureObject:maybeWormholeSecurePasswordId];
        [SecretStore.sharedInstance deleteSecureItem:maybeWormholeSecurePasswordId];
        conveniencePassword = convUnlock;
    }
    else if ( [self isAutoFillConvenienceAutoLockPossible:self.database] ) {
        NSLog(@"AUTOFILL: Within convenience auto unlock timeout. Will auto open...");
        conveniencePassword = self.database.autoFillConvenienceAutoUnlockPassword;
    }
    
    if ( conveniencePassword ) {
        [self unlockWithExplicitPassword:conveniencePassword];
    }
    else {
        [self doRegularUnlockSequence];
    }
}

- (void)manualUnlockDatabase {
    NSLog(@"AUTOFILL: manualUnlockDatabase ENTER");

    MacCompositeKeyDeterminer* det = [MacCompositeKeyDeterminer determinerWithViewController:self
                                                                                    database:self.database
                                                                              isAutoFillOpen:YES
                                                                     isAutoFillQuickTypeOpen:self.quickTypeMode];

    [det getCkfsManually:^(GetCompositeKeyResult result, CompositeKeyFactors * _Nullable factors, BOOL fromConvenience, NSError * _Nullable error) {
        [self handleGetCkfsResult:result factors:factors fromConvenience:fromConvenience error:error];
    }];
}

- (void)doRegularUnlockSequence {
    NSLog(@"AUTOFILL: doRegularUnlockSequence ENTER");

    MacCompositeKeyDeterminer* det = [MacCompositeKeyDeterminer determinerWithViewController:self
                                                                                    database:self.database
                                                                              isAutoFillOpen:YES
                                                                     isAutoFillQuickTypeOpen:self.quickTypeMode];

    [det getCkfs:^(GetCompositeKeyResult result, CompositeKeyFactors * _Nullable factors, BOOL fromConvenience, NSError * _Nullable error) {
        [self handleGetCkfsResult:result factors:factors fromConvenience:fromConvenience error:error];
    }];
}

- (void)unlockWithExplicitPassword:(NSString*)password {
    NSLog(@"AUTOFILL: unlockWithPassword ENTER");

    MacCompositeKeyDeterminer* det = [MacCompositeKeyDeterminer determinerWithViewController:self
                                                                                    database:self.database
                                                                              isAutoFillOpen:YES
                                                                     isAutoFillQuickTypeOpen:self.quickTypeMode];

    [det getCkfsWithExplicitPassword:password
                     keyFileBookmark:self.database.autoFillKeyFileBookmark
                yubiKeyConfiguration:self.database.yubiKeyConfiguration
                          completion:^(GetCompositeKeyResult result, CompositeKeyFactors * _Nullable factors, BOOL fromConvenience, NSError * _Nullable error) {
        [self handleGetCkfsResult:result factors:factors fromConvenience:fromConvenience error:error];
    }];
}

- (void)handleGetCkfsResult:(GetCompositeKeyResult)result
                    factors:(CompositeKeyFactors*)factors
            fromConvenience:(BOOL)fromConvenience
                      error:(NSError*)error {
    NSLog(@"AutoFill -> handleGetCkfsResult [%@] - Error = [%@] - Convenience = [%hhd]", result == kGetCompositeKeyResultSuccess ? @"Succeeded" : @"Failed", error, fromConvenience);

    if ( result == kGetCompositeKeyResultSuccess ) {
        [self unlockDatabaseWithCkf:factors isConvenienceUnlock:fromConvenience];
    }
    else if (result == kGetCompositeKeyResultError ) {
        [MacAlerts error:NSLocalizedString(@"open_sequence_problem_opening_title", @"There was a problem opening the database.")
                   error:error
                  window:self.view.window completion:^{
            [self exitWithErrorOccurred:error];
        }];
    }
    else {
        NSLog(@"AutoFill: Unlock Request Cancelled. NOP.");
        [self exitWithUserCancelled:nil];
    }
}



- (void)unlockDatabaseWithCkf:(CompositeKeyFactors*)ckf
          isConvenienceUnlock:(BOOL)isConvenienceUnlock {
    DatabaseUnlocker *unlocker = [DatabaseUnlocker unlockerForDatabase:self.database
                                                        viewController:self
                                                         forceReadOnly:NO
                                                        isAutoFillOpen:YES
                                                           offlineMode:self.database.offlineMode];
    
    [unlocker unlockLocalWithKey:ckf
              keyFromConvenience:isConvenienceUnlock
                      completion:^(UnlockDatabaseResult result, Model * _Nullable model, NSError * _Nullable innerStreamError, NSError * _Nullable error) {
        NSLog(@"unlockLocalWithKey => [%lu](%@) - error = [%@]", result, result == kUnlockDatabaseResultSuccess ? @"Success" : @"Not Successful", error);
        
        if ( result == kUnlockDatabaseResultSuccess ) {
            [self onSucccesfullyUnlocked:model];
        }
        else if ( result == kUnlockDatabaseResultIncorrectCredentials ) {
            [self manualUnlockDatabase];
        }
        else if ( result == kUnlockDatabaseResultError ) { 
            [MacAlerts error:NSLocalizedString(@"open_sequence_problem_opening_title", @"There was a problem opening the database.")
                       error:error
                      window:self.view.window completion:^{
                [self exitWithErrorOccurred:error];
            }];
        }
        else {
            [self exitWithUserCancelled:nil];
        }
    }];
}

- (void)onSucccesfullyUnlocked:(Model*)model {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.database.autoFillConvenienceAutoUnlockTimeout == -1 && self.withUserInteraction ) {
            [self onboardForAutoFillConvenienceAutoUnlock:^{
                [self continueUnlockedDatabase:model];
            }];
        }
        else {
            [self continueUnlockedDatabase:model];
        }
    });
}

- (void)continueUnlockedDatabase:(Model*)model {
    if ( self.database.autoFillConvenienceAutoUnlockTimeout > 0 ) {
        self.database.autoFillConvenienceAutoUnlockPassword = model.database.ckfs.password;
        [self markLastUnlockedAtTime:self.database];
    }

    if (self.quickTypeIdentifier) {
        [self autoFillWithQuickType:model];
    }
    else {
        [self presentCredentialSelector:model];
    }
}

- (void)onboardForAutoFillConvenienceAutoUnlock:(void (^)(void))completion {
    [MacAlerts threeOptions:NSLocalizedString(@"autofill_auto_unlock_title", @"Auto Unlock Feature")
            informativeText:NSLocalizedString(@"autofill_auto_unlock_message", @"Auto Unlock lets you avoid repeatedly unlocking your database in AutoFill mode within a configurable time window. Would you like to use this handy feature?\n\nNB: Your password is stored in the Secure Enclave for this feature.")
          option1AndDefault:NSLocalizedString(@"autofill_auto_unlock_try_3_minutes", @"Great, lets try 3 mins")
                    option2:NSLocalizedString(@"autofill_auto_unlock_try_10_minutes", @"I'd prefer 10 mins")
                    option3:NSLocalizedString(@"mac_upgrade_no_thanks", @"No Thanks")
                     window:self.view.window
                 completion:^(NSUInteger option) {
        if (option == 1) {
            self.database.autoFillConvenienceAutoUnlockTimeout = 180;
        }
        else if (option == 2) {
            self.database.autoFillConvenienceAutoUnlockTimeout = 600;
        }
        else if (option == 3) {
            self.database.autoFillConvenienceAutoUnlockTimeout = 0;
        }
        
        completion();
    }];
}



- (void)autoFillWithQuickType:(Model*)model {
    NSUUID* uuid = [[NSUUID alloc] initWithUUIDString:self.quickTypeIdentifier.nodeId];
    Node* node = [model getItemById:uuid];
    
    if(node) {
        NSString* password = @"";

        if ( self.quickTypeIdentifier.fieldKey ) {
            StringValue* sv = node.fields.customFields[self.quickTypeIdentifier.fieldKey];
            if ( sv ) {
                password = sv.value;
            }
        }
        else {
            password = [model dereference:node.fields.password node:node];
        }
        
        NSString* user = [model dereference:node.fields.username node:node];
        NSString* totp = node.fields.otpToken ? node.fields.otpToken.password : @"";
        
        password = password ? password : @"";
        [self exitWithCredential:self.database username:user password:password totp:totp];
    }
    else {
        [AutoFillManager.sharedInstance clearAutoFillQuickTypeDatabase];
        
        [MacAlerts info:@"Strongbox: Error Locating This Record"
     informativeText:@"Strongbox could not find this record in the database any longer. It is possibly stale. Strongbox's QuickType AutoFill database has now been cleared, and so you will need to reopen your databases to refresh QuickType AutoFill."
              window:self.view.window
          completion:^{
            [self exitWithErrorOccurred:[Utils createNSError:@"Could not find record in database" errorCode:-1]];
        }];
    }
}

- (void)presentCredentialSelector:(Model*)model {
    NSLog(@"presentCredentialSelector: [%@]", model);
    
    SelectCredential* vc = [[SelectCredential alloc] initWithNibName:@"SelectCredential" bundle:nil];
    vc.model = model;
    vc.serviceIdentifiers = self.serviceIdentifiers;
    vc.onDone = ^(BOOL userCancelled, NSString * _Nullable username, NSString * _Nullable password, NSString * _Nullable totp) {
        if (userCancelled) {
            [self exitWithUserCancelled:self.database];
        }
        else {
            [self exitWithCredential:self.database username:username password:password totp:totp];
        }
    };
    
    [self presentViewControllerAsSheet:vc];
}

- (void)markLastUnlockedAtTime:(MacDatabasePreferences*)database {
    database.autoFillLastUnlockedAt = NSDate.date;
}

- (BOOL)isAutoFillConvenienceAutoLockPossible:(MacDatabasePreferences*)database {
    BOOL isWithinAutoFillConvenienceAutoUnlockTime = NO;
    

    
    if ( database.autoFillLastUnlockedAt != nil && database.autoFillConvenienceAutoUnlockTimeout > 0 ) {
        isWithinAutoFillConvenienceAutoUnlockTime = ![database.autoFillLastUnlockedAt isMoreThanXSecondsAgo:database.autoFillConvenienceAutoUnlockTimeout];

    }
    
    return isWithinAutoFillConvenienceAutoUnlockTime && database.autoFillConvenienceAutoUnlockPassword != nil;
}

- (IBAction)onCancel:(id)sender {
    [self exitWithUserCancelled:nil];
}

@end
