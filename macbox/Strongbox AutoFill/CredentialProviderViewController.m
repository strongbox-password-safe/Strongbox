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
#import "DatabasesManager.h"
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
#import "SelectAutoFillDatabaseViewController.h"
#import "SelectCredential.h"
#import "ProgressWindow.h"
#import "MMWormhole.h"
#import "AutoFillWormhole.h"
#import "SecretStore.h"
#import "Serializator.h"
#import "MacYubiKeyManager.h"
#import "WorkingCopyManager.h"
#import "NSDate+Extensions.h"
#import "MacUrlSchemes.h"
#import "StrongboxErrorCodes.h"

@interface CredentialProviderViewController ()

@property SelectAutoFillDatabaseViewController* selectDbVc;
@property MMWormhole* wormhole;

@property ProgressWindow* progressWindow;
@property NSArray<ASCredentialServiceIdentifier *> *serviceIdentifiers;

@property BOOL withUserInteraction;
@property BOOL quickTypeMode;

@end

static const CGFloat kWormholeWaitTimeout = 0.35f; 

@implementation CredentialProviderViewController

- (void)exitWithUserCancelled:(DatabaseMetadata*)unlockedDatabase {
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

- (void)exitWithCredential:(DatabaseMetadata*)unlockedDatabase username:(NSString*)username password:(NSString*)password totp:(NSString*)totp {
    BOOL pro = Settings.sharedInstance.fullVersion || Settings.sharedInstance.freeTrial;
    
    [self markLastUnlockedAtTime:unlockedDatabase];
    
    if (pro) {
        NSLog(@"EXIT: Success");
        
        if (totp.length) {
            [ClipboardManager.sharedInstance copyConcealedString:totp];
            NSLog(@"Copied TOTP to Pasteboard...");
            
            if ( Settings.sharedInstance.showAutoFillTotpCopiedMessage ) {
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

        if (self.view && self.view.window) {
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

    if (!pro) {
        [self exitWithUserInteractionRequired];
        return;
    }
    
    QuickTypeRecordIdentifier* identifier = [QuickTypeRecordIdentifier fromJson:credentialIdentity.recordIdentifier];
    NSLog(@"Checking wormhole to see if Main App can provide credentials immediately... [%f]", NSDate.date.timeIntervalSince1970);

    if(identifier) {
        DatabaseMetadata* database = [DatabasesManager.sharedInstance.snapshot firstOrDefault:^BOOL(DatabaseMetadata * _Nonnull obj) {
            return [obj.uuid isEqualToString:identifier.databaseId];
        }];

        if (database.quickWormholeFillEnabled) {
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

        DatabaseMetadata* metadata = [DatabasesManager.sharedInstance getDatabaseById:identifier.databaseId];
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

- (void)decodeWormholeMessage:(id)messageObject metadata:(DatabaseMetadata*)metadata {
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
    NSLog(@"initializeQuickType: [%@] => [%@]", credentialIdentity, identifier);
    
    if(identifier) {
        DatabaseMetadata* safe = [DatabasesManager.sharedInstance.snapshot firstOrDefault:^BOOL(DatabaseMetadata * _Nonnull obj) {
            return [obj.uuid isEqualToString:identifier.databaseId];
        }];

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
    NSLog(@"prepareCredentialListForServiceIdentifiers -> serviceIdentifiers = [%@]", serviceIdentifiers);

    __weak CredentialProviderViewController* weakSelf = self;
    self.quickTypeMode = NO;
    self.withUserInteraction = YES;

    self.serviceIdentifiers = serviceIdentifiers;
    
    self.selectDbVc = [[SelectAutoFillDatabaseViewController alloc] initWithNibName:@"SelectAutoFillDatabaseViewController" bundle:nil];

    if ( !self.wormhole ) {
        self.wormhole = [[MMWormhole alloc] initWithApplicationGroupIdentifier:Settings.sharedInstance.appGroupName
                                                             optionalDirectory:kAutoFillWormholeName];
    }
    
    self.selectDbVc.wormhole = self.wormhole;
    
    self.selectDbVc.onDone = ^(BOOL userCancelled, DatabaseMetadata * _Nonnull database) {
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

    NSLog(@"viewWillAppear - [%@]", self.selectDbVc);
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self doNonQuickTypeOnLoadTasks];
    });
}

- (void)doNonQuickTypeOnLoadTasks {

    
    if(!self.quickTypeMode) {
        NSArray<DatabaseMetadata*> *databases = [DatabasesManager.sharedInstance.snapshot filter:^BOOL(DatabaseMetadata * _Nonnull obj) {
            return obj.autoFillEnabled;
        }];

        if ( databases.count == 1 && Settings.sharedInstance.autoFillAutoLaunchSingleDatabase ) {
            NSLog(@"Single Database Launching...");

            DatabaseMetadata* database = databases.firstObject;
            __weak CredentialProviderViewController* weakSelf = self;

            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [weakSelf unlockDatabase:database quickTypeIdentifier:nil serviceIdentifiers:weakSelf.serviceIdentifiers];
            });
        }
        else {
            [self showDatabases];
        }
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




- (BOOL)isLegacyFileUrl:(NSURL*)url {
    return ( url && url.scheme.length && [url.scheme isEqualToString:kStrongboxFileUrlScheme] );
}

- (void)unlockDatabase:(DatabaseMetadata*)database
   quickTypeIdentifier:(QuickTypeRecordIdentifier*_Nullable)quickTypeIdentifier
    serviceIdentifiers:(NSArray<ASCredentialServiceIdentifier *> *)serviceIdentifiers {
    if ( [self isLegacyFileUrl:database.fileUrl] ) {
        [self unlockLegacyFileBasedDatabase:database quickTypeIdentifier:quickTypeIdentifier serviceIdentifiers:serviceIdentifiers];
    }
    else {
        
        if ( !Settings.sharedInstance.isProOrFreeTrial && database.storageProvider != kMacFile ) {
            [MacAlerts info:NSLocalizedString(@"mac_non_file_database_pro_message", @"This database can only be unlocked by Strongbox Pro because it is stored via SFTP or WebDAV.\n\nPlease Upgrade.")
            informativeText:NSLocalizedString(@"mac_non_file_database_pro_message", @"This database can only be unlocked by Strongbox Pro because it is stored via SFTP or WebDAV.\n\nPlease Upgrade.")
                     window:self.view.window
                 completion:^{
                [self exitWithUserCancelled:nil];
            }];
            return;
        }
        
        NSURL* url = [WorkingCopyManager.sharedInstance getLocalWorkingCache2:database.uuid];
        if ( !url ) {
            NSLog(@"Could not find Working Copy");
            NSError* error = [Utils createNSError:@"Could not find local working copy." errorCode:-123];
            [self exitWithErrorOccurred:error];
        }
        else {
            NSLog(@"Got Working Copy OK: [%@]", url);
        }
        
        [self tryWormholeConvenienceUnlock:database url:url quickTypeIdentifier:quickTypeIdentifier serviceIdentifiers:serviceIdentifiers];
    }
}

- (void)unlockLegacyFileBasedDatabase:(DatabaseMetadata*)database
                  quickTypeIdentifier:(QuickTypeRecordIdentifier*_Nullable)quickTypeIdentifier
                   serviceIdentifiers:(NSArray<ASCredentialServiceIdentifier *> *)serviceIdentifiers {
    NSURL* url = nil;
    if (database.autoFillStorageInfo != nil) {
        url = [self tryRefreshBookmark:database];
    }
    
    if (!url) {
        NSString* fmt = NSLocalizedString(@"mac_autofill_first_time_locate-fmt", @"It looks like this is your first time using AutoFill with this database.\n\nFor security reasons you must locate and select your database file for Strongbox so that the AutoFill can access it.\n\nAs a reminder your database file was last located here:\n\n%@\n\nPlease locate it now for Strongbox...");
        NSString* buttonFmt = NSLocalizedString(@"mac_autofill_locate_file_fmt", @"Locate '%@'");

        NSString* welcomeRelocText = [NSString stringWithFormat:fmt, database.fileUrl && database.fileUrl.path ? database.fileUrl.path : NSLocalizedString(@"generic_unknown", @"Unknown")];
        NSString* button = [NSString stringWithFormat:buttonFmt, database.fileUrl && database.fileUrl.lastPathComponent ? database.fileUrl.lastPathComponent : NSLocalizedString(@"generic_unknown", @"Unknown")];
        
        [MacAlerts customOptionWithCancel:NSLocalizedString(@"mac_welcome_to_autofill", @"Welcome to Strongbox AutoFill")
                       informativeText:welcomeRelocText
                     option1AndDefault:button
                              window:self.view.window
                            completion:^(BOOL go) {
            if ( go ) {
                [self beginRelocateDatabaseFileProcedure:database quickTypeIdentifier:quickTypeIdentifier serviceIdentifiers:serviceIdentifiers];
            }
            else {
                [self exitWithUserCancelled:nil];
            }
        }];
    }
    else {
        [self tryWormholeConvenienceUnlock:database url:url quickTypeIdentifier:quickTypeIdentifier serviceIdentifiers:serviceIdentifiers];
    }
}

- (BOOL)isAutoFillConvenienceAutoLockPossible:(DatabaseMetadata*)database {
    BOOL isWithinAutoFillConvenienceAutoUnlockTime = NO;
    
    if ( database.autoFillLastUnlockedAt != nil && database.autoFillConvenienceAutoUnlockTimeout > 0 ) {
        isWithinAutoFillConvenienceAutoUnlockTime = [database.autoFillLastUnlockedAt isMoreThanXSecondsAgo:database.autoFillConvenienceAutoUnlockTimeout];
    }
    
    return isWithinAutoFillConvenienceAutoUnlockTime && database.autoFillConvenienceAutoUnlockPassword != nil;
}

- (void)tryWormholeConvenienceUnlock:(DatabaseMetadata*)database
                                 url:(NSURL*)url
                 quickTypeIdentifier:(QuickTypeRecordIdentifier*)quickTypeIdentifier
                  serviceIdentifiers:(NSArray<ASCredentialServiceIdentifier *> *)serviceIdentifiers {
    if ( !self.wormhole ) {
        self.wormhole = [[MMWormhole alloc] initWithApplicationGroupIdentifier:Settings.sharedInstance.appGroupName
                                                             optionalDirectory:kAutoFillWormholeName];
    }
    
    [self.wormhole clearAllMessageContents];
    
    NSString* requestId = [NSString stringWithFormat:@"%@-%@", kAutoFillWormholeConvUnlockRequestId, database.uuid];

    [self.wormhole passMessageObject:@{ @"user-session-id" : NSUserName(),
                                        @"database-id" : database.uuid }
                          identifier:requestId];
    
    __block NSString* ret = nil;
    dispatch_group_t group = dispatch_group_create();
    dispatch_group_enter(group);

    NSString* responseId = [NSString stringWithFormat:@"%@-%@", kAutoFillWormholeConvUnlockResponseId, database.uuid];
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
            [self unlockDatabaseAtUrl:database
                                  url:url
            wormholeConvenienceUnlock:ret
                  quickTypeIdentifier:quickTypeIdentifier
                   serviceIdentifiers:serviceIdentifiers];
        });
    });
}

- (void)unlockDatabaseAtUrl:(DatabaseMetadata*)database
                        url:(NSURL*)url
  wormholeConvenienceUnlock:(NSString*)wormholeConvenienceUnlock
        quickTypeIdentifier:(QuickTypeRecordIdentifier*)quickTypeIdentifier
         serviceIdentifiers:(NSArray<ASCredentialServiceIdentifier *> *)serviceIdentifiers {
    NSString* conveniencePassword = nil;
    if ( wormholeConvenienceUnlock ) {
        NSLog(@"AUTOFILL: Wormhole convenience unlock found - will unlock database");
        NSString* convUnlock = [SecretStore.sharedInstance getSecureObject:wormholeConvenienceUnlock];
        [SecretStore.sharedInstance deleteSecureItem:wormholeConvenienceUnlock];

        conveniencePassword = convUnlock;
    }
    else if ( [self isAutoFillConvenienceAutoLockPossible:database] ) {
        NSLog(@"AUTOFILL: Within convenience auto unlock timeout. Will auto open...");
        conveniencePassword = database.autoFillConvenienceAutoUnlockPassword;
    }
    
    BOOL keyFileNotSetButRequired = database.keyFileBookmark.length && !database.autoFillKeyFileBookmark.length;

    if ( keyFileNotSetButRequired ) {
        NSLog(@"Unlock Database: keyFileNotSetButRequired Showing Manual Unlock to allow user to select...");
        [self manualUnlockDatabase:database url:url quickTypeIdentifier:quickTypeIdentifier serviceIdentifiers:serviceIdentifiers];
    }
    else if ( conveniencePassword ) {
        NSError* err;
        CompositeKeyFactors* ckf = [self getCompositeKeyFactorsWithSelectedUiFactors:conveniencePassword
                                                                     keyFileBookmark:database.autoFillKeyFileBookmark
                                                                yubiKeyConfiguration:database.yubiKeyConfiguration
                                                                                 url:url
                                                                            metadata:database
                                                                 isConvenienceUnlock:YES
                                                                               error:&err];
        if( !ckf || err) {
            [MacAlerts error:err window:self.view.window completion:^{
                [self exitWithErrorOccurred:err];
            }];
        }
        else {
            [self unlockDatabaseWithCkf:database url:url quickTypeIdentifier:quickTypeIdentifier ckf:ckf isConvenienceUnlock:YES serviceIdentifiers:serviceIdentifiers];
        }
    }
    else {
        BOOL pro = Settings.sharedInstance.fullVersion || Settings.sharedInstance.freeTrial;
        BOOL convenienceAvailable = [BiometricIdHelper.sharedInstance convenienceAvailable:database];
        BOOL convenienceEnabled = database.isTouchIdEnabled || database.isWatchUnlockEnabled;
        BOOL passwordAvailable = database.conveniencePassword.length;
            
        if (convenienceEnabled && pro && database.isTouchIdEnrolled && convenienceAvailable && passwordAvailable ) {
            NSLog(@"Unlock Database: Biometric Possible & Available...");

            
            
            
            

            [self convenienceUnlockDatabase:database
                                        url:url
                        quickTypeIdentifier:quickTypeIdentifier
                         serviceIdentifiers:serviceIdentifiers];
        }
        else {
            NSLog(@"Unlock Database: Biometric Not Possible or Available...");
            [self manualUnlockDatabase:database url:url quickTypeIdentifier:quickTypeIdentifier serviceIdentifiers:serviceIdentifiers];
        }
    }
}

- (void)convenienceUnlockDatabase:(DatabaseMetadata*)database
                              url:(NSURL*)url
              quickTypeIdentifier:(QuickTypeRecordIdentifier*)quickTypeIdentifier
               serviceIdentifiers:(NSArray<ASCredentialServiceIdentifier *> *)serviceIdentifiers {
    NSString* localizedFallbackTitle = NSLocalizedString(@"safes_vc_unlock_manual_action", @"Manual Unlock");
    
    [BiometricIdHelper.sharedInstance authorize:localizedFallbackTitle database:database completion:^(BOOL success, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if(success) {
                NSError* err;
        
                CompositeKeyFactors* ckf = [self getCompositeKeyFactorsWithSelectedUiFactors:database.conveniencePassword
                                                                             keyFileBookmark:database.autoFillKeyFileBookmark
                                                                        yubiKeyConfiguration:database.yubiKeyConfiguration
                                                                                         url:url
                                                                                    metadata:database
                                                                         isConvenienceUnlock:YES
                                                                                       error:&err];
                if( !ckf || err) {
                    [MacAlerts error:err window:self.view.window completion:^{
                        [self exitWithErrorOccurred:err];
                    }];
                }
                else {
                    [self unlockDatabaseWithCkf:database url:url quickTypeIdentifier:quickTypeIdentifier ckf:ckf isConvenienceUnlock:YES serviceIdentifiers:serviceIdentifiers];
                }
            }
            else {
                NSLog(@"Error unlocking safe with Touch ID. [%@]", error);
                
                if(error && error.code == LAErrorUserFallback) {
                    [self manualUnlockDatabase:database url:url quickTypeIdentifier:quickTypeIdentifier serviceIdentifiers:serviceIdentifiers];
                }
                else if (error && (error.code == LAErrorUserCancel || error.code == -2412)) {
                    NSLog(@"User cancelled or selected fallback. Ignore...");
                    [self exitWithUserCancelled:nil];
                }
                else {
                    [MacAlerts error:error window:self.view.window];
                    [self exitWithErrorOccurred:error];
                }
            }
        });
    }];
}

- (void)manualUnlockDatabase:(DatabaseMetadata*)database
                         url:(NSURL*)url
         quickTypeIdentifier:(QuickTypeRecordIdentifier*)quickTypeIdentifier
          serviceIdentifiers:(NSArray<ASCredentialServiceIdentifier *> *)serviceIdentifiers {
    ManualCredentialsEntry* mce = [[ManualCredentialsEntry alloc] initWithNibName:@"ManualCredentialsEntry" bundle:nil];
    mce.databaseUuid = database.uuid;
    mce.isAutoFillOpen = YES;
    
    mce.onDone = ^(BOOL userCancelled, NSString * _Nullable password, NSString * _Nullable keyFileBookmark, YubiKeyConfiguration * _Nullable yubiKeyConfiguration) {
        if (userCancelled) {
            [self exitWithUserCancelled:nil];
        }
        else {
            NSError* error;
            CompositeKeyFactors* ckf = [self getCompositeKeyFactorsWithSelectedUiFactors:password
                                                                         keyFileBookmark:keyFileBookmark
                                                                    yubiKeyConfiguration:yubiKeyConfiguration
                                                                                     url:url
                                                                                metadata:database
                                                                     isConvenienceUnlock:NO
                                                                                   error:&error];
            
            if( !ckf || error) {
                [MacAlerts error:error window:self.view.window completion:^{
                    [self exitWithErrorOccurred:error];
                }];
            }
            else {
                database.autoFillKeyFileBookmark = keyFileBookmark;
                [DatabasesManager.sharedInstance atomicUpdate:database.uuid touch:^(DatabaseMetadata * _Nonnull metadata) {
                    metadata.autoFillKeyFileBookmark = keyFileBookmark;
                }];
                
                [self unlockDatabaseWithCkf:database
                                        url:url
                        quickTypeIdentifier:quickTypeIdentifier
                                        ckf:ckf
                        isConvenienceUnlock:NO
                         serviceIdentifiers:serviceIdentifiers];
            }
        }
    };
    
    [self presentViewControllerAsSheet:mce];
}

- (CompositeKeyFactors*)getCompositeKeyFactorsWithSelectedUiFactors:(NSString*)password
                                                    keyFileBookmark:(NSString*)keyFileBookmark
                                               yubiKeyConfiguration:(YubiKeyConfiguration * _Nullable)yubiKeyConfiguration
                                                                url:(NSURL*)url
                                                            metadata:(DatabaseMetadata*)metadata
                                                isConvenienceUnlock:(BOOL)isConvenienceUnlock
                                                              error:(NSError**)error {
    BOOL securitySucceeded = [url startAccessingSecurityScopedResource];
    DatabaseFormat format = [Serializator getDatabaseFormat:url];
    if ( securitySucceeded ) {
        [url stopAccessingSecurityScopedResource];
    }
    
    NSData* keyFileDigest = [self getSelectedKeyFileDigest:metadata format:format bookmark:keyFileBookmark isConvenienceUnlock:isConvenienceUnlock error:error];
    if(*error) {
        return nil;
    }
        
    if ( yubiKeyConfiguration == nil ) {
        return [CompositeKeyFactors password:password keyFileDigest:keyFileDigest];
    }
    else {
        __block YubiKeyData * _Nonnull foundYubiKey;
        
        dispatch_group_t group = dispatch_group_create();
        dispatch_group_enter(group);
        [MacYubiKeyManager.sharedInstance getAvailableYubiKey:^(YubiKeyData * _Nonnull yubiKeyData) {
            foundYubiKey = yubiKeyData;
            dispatch_group_leave(group);
        }];
        dispatch_group_wait(group, DISPATCH_TIME_FOREVER);

        if ( foundYubiKey == nil || ![foundYubiKey.serial isEqualToString:yubiKeyConfiguration.deviceSerial]) {
            if (error) {
                NSString* errorMessage = NSLocalizedString(@"mac_autofill_no_or_incorrect_yubikey_found", @"Your Database is configured to use a YubiKey, however no YubiKey or an incorrect YubiKey was found connected.");
                *error = [Utils createNSError:errorMessage errorCode:-24123];
            }
            return nil;
        }
        else {
            NSInteger slot = yubiKeyConfiguration.slot;
            BOOL currentYubiKeySlot1IsBlocking = foundYubiKey.slot1CrStatus == YubiKeySlotCrStatusSupportedBlocking;
            BOOL currentYubiKeySlot2IsBlocking = foundYubiKey.slot2CrStatus == YubiKeySlotCrStatusSupportedBlocking;
            BOOL blocking = slot == 1 ? currentYubiKeySlot1IsBlocking : currentYubiKeySlot2IsBlocking;

            NSWindow* windowHint = self.view.window; 

            return [CompositeKeyFactors password:password
                                   keyFileDigest:keyFileDigest
                                       yubiKeyCR:^(NSData * _Nonnull challenge, YubiKeyCRResponseBlock  _Nonnull completion) {
                [MacYubiKeyManager.sharedInstance compositeKeyFactorCr:challenge
                                                            windowHint:windowHint
                                                                  slot:slot
                                                        slotIsBlocking:blocking
                                                            completion:completion];
            }];
        }
    }
}

- (NSData*)getSelectedKeyFileDigest:(DatabaseMetadata*)metadata format:(DatabaseFormat)format bookmark:(NSString*)bookmark isConvenienceUnlock:(BOOL)isConvenienceUnlock error:(NSError**)error {
    NSData* keyFileDigest = nil;

    if(bookmark) {
        NSData* data = [BookmarksHelper dataWithContentsOfBookmark:bookmark error:error];

        if(data) {
            keyFileDigest = [KeyFileParser getNonePerformantKeyFileDigest:data checkForXml:format != kKeePass1];
        }
        else {
            if ( isConvenienceUnlock ) {
                NSLog(@"Could not read Key File with Convenience Unlock. Clearing Secure Convenience Items");
                [metadata resetConveniencePasswordWithCurrentConfiguration:nil];
                metadata.autoFillConvenienceAutoUnlockPassword = nil;
            }
            
            if (error) {
                *error = [Utils createNSError:@"Could not read key file..."  errorCode:-1];
            }
        }
    }

    return keyFileDigest;
}

- (void)showProgressModal:(NSString*)operationDescription {
    dispatch_async(dispatch_get_main_queue(), ^{
        if ( self.progressWindow ) {
            [self.progressWindow hide];
        }
        self.progressWindow = [ProgressWindow newProgress:operationDescription];
        [self.view.window beginSheet:self.progressWindow.window completionHandler:nil];
    });
}

- (void)hideProgressModal {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.progressWindow hide];
    });
}

- (void)unlockDatabaseWithCkf:(DatabaseMetadata*)database
                          url:(NSURL*)url
          quickTypeIdentifier:(QuickTypeRecordIdentifier*)quickTypeIdentifier
                          ckf:(CompositeKeyFactors*)ckf
          isConvenienceUnlock:(BOOL)isConvenienceUnlock
           serviceIdentifiers:(NSArray<ASCredentialServiceIdentifier *> *)serviceIdentifiers {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0L), ^{
        [self _unlockDatabaseWithCkf:database
                                 url:url
                 quickTypeIdentifier:quickTypeIdentifier
                                 ckf:ckf
                 isConvenienceUnlock:isConvenienceUnlock
                  serviceIdentifiers:serviceIdentifiers];
    });
}

- (void)_unlockDatabaseWithCkf:(DatabaseMetadata*)database
                           url:(NSURL*)url
           quickTypeIdentifier:(QuickTypeRecordIdentifier*)quickTypeIdentifier
                           ckf:(CompositeKeyFactors*)ckf
           isConvenienceUnlock:(BOOL)isConvenienceUnlock
            serviceIdentifiers:(NSArray<ASCredentialServiceIdentifier *> *)serviceIdentifiers {
    BOOL securitySucceeded = [url startAccessingSecurityScopedResource];

    NSString* loc = NSLocalizedString(@"generic_unlocking_ellipsis", @"Unlocking...");
    [self showProgressModal:loc];
    
    [Serializator fromUrl:url
                      ckf:ckf
                   config:DatabaseModelConfig.defaults
               completion:^(BOOL userCancelled, DatabaseModel * _Nullable model, NSError * _Nullable innerStreamError, NSError * _Nullable error) {
        NSLog(@"AutoFill: Open Database: userCancelled = [%d] - Model=[%@] - Error = [%@]", userCancelled, model, error);
        dispatch_async(dispatch_get_main_queue(), ^{
            [self hideProgressModal];
            
            NSError* aggregatedError = error ? error : innerStreamError; 

            if( aggregatedError ) {
                [self exitWithUserCancelled:database]; 
            }
            else if ( model ) {
                [self onSucccesfullyUnlockedDatabase:database
                                               model:model
                                 quickTypeIdentifier:quickTypeIdentifier
                                  serviceIdentifiers:serviceIdentifiers];
            }
            else {
                if ( isConvenienceUnlock && error.code == StrongboxErrorCodes.incorrectCredentials ) {
                    NSLog(@"Incorrect Credentials with Convenience Unlock. Clearing Secure Convenience Items");
                    [database resetConveniencePasswordWithCurrentConfiguration:nil];
                    database.autoFillConvenienceAutoUnlockPassword = nil;
                }
                
                [MacAlerts error:NSLocalizedString(@"cred_vc_error_opening_title", @"Strongbox: Error Opening Database")
                        error:error
                       window:self.view.window
                   completion:^{
                    [self exitWithErrorOccurred:error ? error : [Utils createNSError:@"Could not open database" errorCode:-1]];
                }];
            }
            
            if ( securitySucceeded ) {
                [url stopAccessingSecurityScopedResource];
            }
        });
    }];
}



- (void)onSucccesfullyUnlockedDatabase:(DatabaseMetadata*)metadata
                                 model:(DatabaseModel*)model
                   quickTypeIdentifier:(QuickTypeRecordIdentifier*)quickTypeIdentifier
                    serviceIdentifiers:(NSArray<ASCredentialServiceIdentifier *> *)serviceIdentifiers {
    
    if (metadata.autoFillConvenienceAutoUnlockTimeout == -1 && self.withUserInteraction ) {
        [self onboardForAutoFillConvenienceAutoUnlock:metadata
                                           completion:^{
            [self continueUnlockedDatabase:metadata model:model quickTypeIdentifier:quickTypeIdentifier serviceIdentifiers:serviceIdentifiers];
        }];
    }
    else {
        [self continueUnlockedDatabase:metadata model:model quickTypeIdentifier:quickTypeIdentifier serviceIdentifiers:serviceIdentifiers];
    }
}

- (void)continueUnlockedDatabase:(DatabaseMetadata*)metadata
                           model:(DatabaseModel*)model
             quickTypeIdentifier:(QuickTypeRecordIdentifier*)quickTypeIdentifier
              serviceIdentifiers:(NSArray<ASCredentialServiceIdentifier *> *)serviceIdentifiers {
    if ( metadata.autoFillConvenienceAutoUnlockTimeout > 0 ) {
        metadata.autoFillConvenienceAutoUnlockPassword = model.ckfs.password;
        [self markLastUnlockedAtTime:metadata];
    }
    
    if (quickTypeIdentifier) {
        [self autoFillWithQuickType:metadata model:model quickTypeIdentifier:quickTypeIdentifier];
    }
    else {
        [self presentCredentialSelector:metadata model:model serviceIdentifiers:serviceIdentifiers];
    }
}

- (void)onboardForAutoFillConvenienceAutoUnlock:(DatabaseMetadata *)database completion:(void (^)(void))completion {
    [MacAlerts threeOptions:NSLocalizedString(@"autofill_auto_unlock_title", @"Auto Unlock Feature")
            informativeText:NSLocalizedString(@"autofill_auto_unlock_message", @"Auto Unlock lets you avoid repeatedly unlocking your database in AutoFill mode within a configurable time window. Would you like to use this handy feature?\n\nNB: Your password is stored in the Secure Enclave for this feature.")
          option1AndDefault:NSLocalizedString(@"autofill_auto_unlock_try_3_minutes", @"Great, lets try 3 mins")
                    option2:NSLocalizedString(@"autofill_auto_unlock_try_10_minutes", @"I'd prefer 10 mins")
                    option3:NSLocalizedString(@"mac_upgrade_no_thanks", @"No Thanks")
                     window:self.view.window
                 completion:^(NSUInteger option) {
        if (option == 1) {
            database.autoFillConvenienceAutoUnlockTimeout = 180;
            [DatabasesManager.sharedInstance atomicUpdate:database.uuid touch:^(DatabaseMetadata * _Nonnull metadata) {
                metadata.autoFillConvenienceAutoUnlockTimeout = 180;
            }];
        }
        else if (option == 2) {
            database.autoFillConvenienceAutoUnlockTimeout = 600;
            [DatabasesManager.sharedInstance atomicUpdate:database.uuid touch:^(DatabaseMetadata * _Nonnull metadata) {
                metadata.autoFillConvenienceAutoUnlockTimeout = 600;
            }];
        }
        else if (option == 3) {
            database.autoFillConvenienceAutoUnlockTimeout = 0;
            [DatabasesManager.sharedInstance atomicUpdate:database.uuid touch:^(DatabaseMetadata * _Nonnull metadata) {
                metadata.autoFillConvenienceAutoUnlockTimeout = 0;
            }];
        }
        
        completion();
    }];
}


- (void)autoFillWithQuickType:(DatabaseMetadata*)metadata model:(DatabaseModel*)model quickTypeIdentifier:(QuickTypeRecordIdentifier*)quickTypeIdentifier {
    Node* node = [model.effectiveRootGroup.allChildRecords firstOrDefault:^BOOL(Node * _Nonnull obj) {
        return [obj.uuid.UUIDString isEqualToString:quickTypeIdentifier.nodeId]; 
    }];
    
    if(node) {
        NSString* user = [model dereference:node.fields.username node:node];
        NSString* password = [model dereference:node.fields.password node:node];
        NSString* totp = node.fields.otpToken ? node.fields.otpToken.password : @"";
        
        [self exitWithCredential:metadata username:user password:password totp:totp];
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

- (void)presentCredentialSelector:(DatabaseMetadata*)metadata model:(DatabaseModel*)model serviceIdentifiers:(NSArray<ASCredentialServiceIdentifier *> *)serviceIdentifiers {
    NSLog(@"presentCredentialSelector: [%@]", model);
    
    SelectCredential* vc = [[SelectCredential alloc] initWithNibName:@"SelectCredential" bundle:nil];
    vc.model = model;
    vc.serviceIdentifiers = serviceIdentifiers;
    vc.onDone = ^(BOOL userCancelled, NSString * _Nullable username, NSString * _Nullable password, NSString * _Nullable totp) {
        if (userCancelled) {
            [self exitWithUserCancelled:metadata];
        }
        else {
            [self exitWithCredential:metadata username:username password:password totp:totp];
        }
    };
    
    [self presentViewControllerAsSheet:vc];
}



- (NSURL*)tryRefreshBookmark:(DatabaseMetadata*)database {
    NSError *error = nil;
    NSString* updatedBookmark;
    NSURL* url = [BookmarksHelper getUrlFromBookmark:database.autoFillStorageInfo
                                     readOnly:NO
                              updatedBookmark:&updatedBookmark
                                        error:&error];
    
    if(url == nil) {
        NSLog(@"WARN: Could not resolve bookmark for database...");
    }
    else if (updatedBookmark) {
        database.autoFillStorageInfo = updatedBookmark;
        [DatabasesManager.sharedInstance atomicUpdate:database.uuid touch:^(DatabaseMetadata * _Nonnull metadata) {
            metadata.autoFillStorageInfo = updatedBookmark;
        }];
    }
    
    return url;
}

- (void)beginRelocateDatabaseFileProcedure:(DatabaseMetadata*)database
                       quickTypeIdentifier:(QuickTypeRecordIdentifier*_Nullable)quickTypeIdentifier
                        serviceIdentifiers:(NSArray<ASCredentialServiceIdentifier *> *)serviceIdentifiers {
    NSOpenPanel *op = [NSOpenPanel openPanel];
    
    op.canChooseFiles = YES;
    op.allowsMultipleSelection = NO;
    op.canChooseDirectories = NO;
    
    op.message = [NSString stringWithFormat:@"Locate '%@' Database File", database.fileUrl.lastPathComponent];

    op.directoryURL = database.fileUrl.URLByDeletingLastPathComponent;
    op.nameFieldStringValue = database.fileUrl.lastPathComponent;
    
    NSModalResponse response = [op runModal];
    
    if (response == NSModalResponseCancel || op.URLs.firstObject == nil) {
        [self exitWithUserCancelled:nil];
        return;
    }
    
    NSURL* url = [op.URLs firstObject];
    
    [self validateRelocatedDatabase:url database:database quickTypeIdentifier:quickTypeIdentifier serviceIdentifiers:serviceIdentifiers];
}

- (void)validateRelocatedDatabase:(NSURL*)url
                         database:(DatabaseMetadata*)database
              quickTypeIdentifier:(QuickTypeRecordIdentifier*_Nullable)quickTypeIdentifier
               serviceIdentifiers:(NSArray<ASCredentialServiceIdentifier *> *)serviceIdentifiers {;
    NSError* error;
    BOOL valid = [Serializator isValidDatabase:url error:&error];
    if (!valid) {
        [MacAlerts error:[NSString stringWithFormat:NSLocalizedString(@"open_sequence_invalid_database_filename_fmt", @"Invalid Database - [%@]")]
                error:error
               window:self.view.window completion:^{
            [self exitWithUserCancelled:nil];
        }];
        return;
    }

    if([url.lastPathComponent compare:database.fileUrl.lastPathComponent] != NSOrderedSame) {
        [MacAlerts yesNo:NSLocalizedString(@"open_sequence_database_different_filename_title",@"Different Filename")
      informativeText:NSLocalizedString(@"open_sequence_database_different_filename_message",@"This doesn't look like it's the right file because the filename looks different than the one you originally added. Do you want to continue?")
               window:self.view.window
           completion:^(BOOL yesNo) {
           if(yesNo) {
               [self updateFilesBookmarkWithRelocatedUrl:url database:database quickTypeIdentifier:quickTypeIdentifier serviceIdentifiers:serviceIdentifiers];
           }
           else {
               [self exitWithUserCancelled:nil];
           }
        }];
    }
    else {
        [self updateFilesBookmarkWithRelocatedUrl:url database:database quickTypeIdentifier:quickTypeIdentifier serviceIdentifiers:serviceIdentifiers];
    }
}
        
- (void)updateFilesBookmarkWithRelocatedUrl:(NSURL*)url
                                   database:(DatabaseMetadata*)database
                        quickTypeIdentifier:(QuickTypeRecordIdentifier*_Nullable)quickTypeIdentifier
                         serviceIdentifiers:(NSArray<ASCredentialServiceIdentifier *> *)serviceIdentifiers {
    NSError* error;
    NSString* bookmark = [BookmarksHelper getBookmarkFromUrl:url readOnly:NO error:&error];
    
    if (bookmark && !error) {
        database.autoFillStorageInfo = bookmark;
        [DatabasesManager.sharedInstance atomicUpdate:database.uuid touch:^(DatabaseMetadata * _Nonnull metadata) {
            metadata.autoFillStorageInfo = bookmark;
        }];

        [self tryWormholeConvenienceUnlock:database url:url quickTypeIdentifier:quickTypeIdentifier serviceIdentifiers:serviceIdentifiers];
    }
    else {
        NSLog(@"WARNWARN: Could not bookmark user selected file in AutoFill: [%@]", error);
        [MacAlerts error:NSLocalizedString(@"open_sequence_error_could_not_bookmark_file", @"Could not bookmark this file")
                error:error
               window:self.view.window];
    }
}

- (void)markLastUnlockedAtTime:(DatabaseMetadata*)database {
    database.autoFillLastUnlockedAt = NSDate.date;
    [DatabasesManager.sharedInstance atomicUpdate:database.uuid
                                            touch:^(DatabaseMetadata * _Nonnull metadata) {
        metadata.autoFillLastUnlockedAt = database.autoFillLastUnlockedAt;
    }];
}

@end
