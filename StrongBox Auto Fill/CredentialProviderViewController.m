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

#import "Model.h"
#import "IOSCompositeKeyDeterminer.h"
#import "DatabaseUnlocker.h"
#import "DuressActionHelper.h"
#import "WorkingCopyManager.h"
#import "SecretStore.h"
#import "NSDate+Extensions.h"
#import "PickCredentialsTableViewController.h"
#import "EntryViewModel.h"
#import "Node+Passkey.h"
#import "StrongboxiOSFilesManager.h"

#ifndef IS_APP_EXTENSION
#import "Strongbox-Swift.h"
#else
#import "Strongbox_Auto_Fill-Swift.h"
#endif

#import "AutoFillDarwinNotification.h"

typedef enum : NSUInteger {
    AutoFillOperationModeGetPasswordManualSelect,
    AutoFillOperationModeGetPasswordQuickType,
    AutoFillOperationModeRegisterPasskey,
    AutoFillOperationModeGetPasskeyAssertionManualOrQuickTypeWithUI,
    AutoFillOperationModeGetPasskeyAssertionQuickTypeNoUI,
    AutoFillOperationModeTextToInsert,
    AutoFillOperationMode2FACodeFillQuickType,
    AutoFillOperationMode2FACodeFillManualOrQuickTypeWithUI,
} AutoFillOperationMode;

@interface CredentialProviderViewController () <UIAdaptivePresentationControllerDelegate>

@property (nonatomic, strong) UINavigationController* currentlyPresentedNavController; 

@property (nonatomic, strong) NSArray<ASCredentialServiceIdentifier *> * serviceIdentifiers;

@property id credentialIdentity;
@property id passkeyCredentialRequest;
@property (readonly) UIViewController* vcToPresentOn;

@property AutoFillOperationMode mode;
@property BOOL initializedUI;







@property BOOL withoutUserInteraction;
@property BOOL hasDoneCommonInit;

@end

@implementation CredentialProviderViewController

- (void)commonInit {
    if ( !self.hasDoneCommonInit ) {
        self.hasDoneCommonInit = YES;
        
        slog(@"🟢 CredentialProviderViewController::commonInit"); 
                
        [StrongboxFilesManager.sharedInstance deleteAllTmpDirectoryFiles];
        
        [DatabasePreferences reloadIfChangedByOtherComponent]; 
    }
    else {
        slog(@"🟢 CredentialProviderViewController::commonInit already done");
    }
}



- (void)provideCredentialWithoutUserInteractionForIdentity:(ASPasswordCredentialIdentity *)credentialIdentity {
    slog(@"🟢 provideCredentialWithoutUserInteractionForIdentity: [%@]", credentialIdentity);
    [self commonInit];
    
    self.mode = AutoFillOperationModeGetPasswordQuickType;
    self.withoutUserInteraction = YES;
    
    self.credentialIdentity = credentialIdentity;
    
    QuickTypeRecordIdentifier* identifier = [QuickTypeRecordIdentifier fromJson:credentialIdentity.recordIdentifier];
    DatabasePreferences* database = [self getDatabaseFromQuickTypeIdentifier:identifier];
    
    if ( database ) {
        slog(@"🟢 provideCredentialWithoutUserInteractionForIdentity - Got DB");
        
        IOSCompositeKeyDeterminer* keyDeterminer = [IOSCompositeKeyDeterminer determinerWithViewController:self
                                                                                                  database:database
                                                                                            isAutoFillOpen:YES
                                                                transparentAutoFillBackgroundForBiometrics:YES
                                                                                       biometricPreCleared:NO
                                                                                       noConvenienceUnlock:NO];
        if ( keyDeterminer.isAutoFillConvenienceAutoLockPossible ) {
            slog(@"🟢 provideCredentialWithoutUserInteractionForIdentity - Within Convenience Timeout - Filling without UI");
            [self unlockDatabase:database identifier:identifier transparentBio:YES];
            return;
        }
        else {
            slog(@"🟢 provideCredentialWithoutUserInteractionForIdentity - Not Unlocked or Within Convenience Timeout - Exiting UI Required");
        }
    }
    
    [self exitWithUserInteractionRequired];
}

- (void)prepareInterfaceToProvideCredentialForIdentity:(ASPasswordCredentialIdentity *)credentialIdentity {
    slog(@"🟢 prepareInterfaceToProvideCredentialForIdentity = %@", credentialIdentity);
    [self commonInit];
    
    self.mode = AutoFillOperationModeGetPasswordQuickType;
    self.credentialIdentity = credentialIdentity;
}

- (void)prepareCredentialListForServiceIdentifiers:(NSArray<ASCredentialServiceIdentifier *> *)serviceIdentifiers {
    slog(@"🐞 prepareCredentialListForServiceIdentifiers = %@ - nav = [%@]", serviceIdentifiers, self.navigationController);
    [self commonInit];
    
    self.mode = AutoFillOperationModeGetPasswordManualSelect;
    self.serviceIdentifiers = serviceIdentifiers;
}



- (void)prepareInterfaceForUserChoosingTextToInsert {
    slog(@"🐞 prepareInterfaceForUserChoosingTextToInsert");
    [self commonInit];
    
    self.mode = AutoFillOperationModeTextToInsert;
    self.serviceIdentifiers = @[];
}

- (void)prepareOneTimeCodeCredentialListForServiceIdentifiers:(NSArray<ASCredentialServiceIdentifier *> *)serviceIdentifiers {
    slog(@"🐞 prepareOneTimeCodeCredentialListForServiceIdentifiers: [%@]", serviceIdentifiers);
    [self commonInit];
    
    self.mode = AutoFillOperationMode2FACodeFillManualOrQuickTypeWithUI;
    self.serviceIdentifiers = serviceIdentifiers;
}



- (void)prepareInterfaceForPasskeyRegistration:(id<ASCredentialRequest>)registrationRequest {
    slog(@"🟢 prepareInterfaceForPasskeyRegistration [%@]", registrationRequest);
    [self commonInit];
    
    self.mode = AutoFillOperationModeRegisterPasskey;
    self.passkeyCredentialRequest = registrationRequest;
    
    [self delayedInitializeUI];
}

- (void)provideCredentialWithoutUserInteractionForRequest:(id<ASCredentialRequest>)credentialRequest {
    slog(@"🟢 provideCredentialWithoutUserInteractionForRequest [%@]", credentialRequest);
    [self commonInit];

    id<ASCredentialIdentity> credentialIdentity = credentialRequest.credentialIdentity;
    QuickTypeRecordIdentifier* identifier = [QuickTypeRecordIdentifier fromJson:credentialIdentity.recordIdentifier];
    DatabasePreferences* database = [self getDatabaseFromQuickTypeIdentifier:identifier];
    if ( !database ) {
        [self exitWithUserInteractionRequired];
    }
    
    if ( credentialRequest.type == ASCredentialRequestTypePasskeyAssertion ) {
        self.mode = AutoFillOperationModeGetPasskeyAssertionQuickTypeNoUI;
        self.withoutUserInteraction = YES;
        self.passkeyCredentialRequest = credentialRequest;
                
        if ( ![self unlockIfPossibleWithoutUserInteraction:database identifier:identifier] ) {
            [self exitWithUserInteractionRequired];
        }
    }
    else if (@available(iOS 18.0, *)) {
        if ( credentialRequest.type == ASCredentialRequestTypeOneTimeCode ) {
            self.mode = AutoFillOperationMode2FACodeFillQuickType;
            self.withoutUserInteraction = YES;
            self.credentialIdentity = credentialIdentity;

            if ( ![self unlockIfPossibleWithoutUserInteraction:database identifier:identifier] ) {
                [self exitWithUserInteractionRequired];
            }
        }
    }
    else {
        [self provideCredentialWithoutUserInteractionForIdentity:(ASPasswordCredentialIdentity*)credentialRequest.credentialIdentity];
    }
}

- (BOOL)unlockIfPossibleWithoutUserInteraction:(DatabasePreferences*)database identifier:(QuickTypeRecordIdentifier*)identifier {
    slog(@"provideCredentialWithoutUserInteractionForRequest - Passkey or 2FA Code AutoFill without UI - Got DB");
    
    IOSCompositeKeyDeterminer* keyDeterminer = [IOSCompositeKeyDeterminer determinerWithViewController:self
                                                                                              database:database
                                                                                        isAutoFillOpen:YES
                                                            transparentAutoFillBackgroundForBiometrics:YES
                                                                                   biometricPreCleared:NO
                                                                                   noConvenienceUnlock:NO];
    if ( keyDeterminer.isAutoFillConvenienceAutoLockPossible ) {
        slog(@"provideCredentialWithoutUserInteractionForRequest - Passkey - Within Timeout - Filling without UI");
        [self unlockDatabase:database identifier:identifier transparentBio:YES];
        return YES;
    }
    
    return NO;
}

- (void)prepareInterfaceToProvideCredentialForRequest:(id<ASCredentialRequest>)credentialRequest {
    slog(@"🟢 prepareInterfaceToProvideCredentialForRequest [%@]", credentialRequest);
    [self commonInit];
    
    if ( credentialRequest.type == ASCredentialRequestTypePasskeyAssertion ) {
        self.mode = AutoFillOperationModeGetPasskeyAssertionManualOrQuickTypeWithUI;
        self.passkeyCredentialRequest = credentialRequest;
        self.credentialIdentity = credentialRequest.credentialIdentity;
        
        
        
        
    }
    else if (@available(iOS 18.0, *)) {
        if ( credentialRequest.type == ASCredentialRequestTypeOneTimeCode ) {
            self.mode = AutoFillOperationMode2FACodeFillQuickType;
            self.credentialIdentity = credentialRequest.credentialIdentity;
        }
    }
    else {
        [self prepareInterfaceToProvideCredentialForIdentity:(ASPasswordCredentialIdentity*)credentialRequest.credentialIdentity];
    }
}



- (void)viewDidLoad {
    [super viewDidLoad];
    
    slog(@"🟢 viewDidLoad");
    
    [self delayedInitializeUI];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    slog(@"🟢 viewWillAppear");
    
    [self initializeUI:NO];
}

- (void)delayedInitializeUI {
    __weak CredentialProviderViewController* weakSelf = self;
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.35 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [weakSelf tryInitializeUI];
    });
}

- (void)tryInitializeUI {
    if ( self.initializedUI ) {
        slog(@"🟢 tryInitializeUI but already initialized Done");
        return;
    }
    
    if ( self.isViewLoaded ) {
        slog(@"🟢 tryInitializeUI - UI is loaded!");
        [self initializeUI:YES];
    }
    else {
        slog(@"🟢 tryInitializeUI - UI is NOT loaded! will try again in a sec...");
        [self delayedInitializeUI];
    }
}

- (void)initializeUI:(BOOL)delayed {
    if ( self.initializedUI ) {
        slog(@"🟢 initializeUI called again - Already Done");
        return;
    }
    self.initializedUI = YES;
    
    slog(@"🟢 initializeUI - delay = %hhd", delayed);
    
    
    
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
    if ( self.mode == AutoFillOperationModeRegisterPasskey ) { 
        slog(@"🟢 startup UI: Passkey Registration...");
        [self launchSingleOrRequestDatabaseSelection];
    }
    else if ( self.mode == AutoFillOperationModeGetPasskeyAssertionManualOrQuickTypeWithUI ) { 
        if ( self.credentialIdentity ) {
            slog(@"🟢 startup UI: Passkey Assertion with QuickType ID...");
            [self unlockWithQuickTypeIdentifier];
        }
        else {
            slog(@"🟢 startup UI: Passkey Assertion with manual select...");
            [self launchSingleOrRequestDatabaseSelection];
        }
    }
    else if ( self.mode == AutoFillOperationModeGetPasskeyAssertionQuickTypeNoUI ) {
        slog(@"🔴 startup UI: Passkey AssertionQuickType No UI - Shouldn't be possible..."); 
    }
    else if ( self.mode == AutoFillOperationModeGetPasswordQuickType ) {
        slog(@"🟢 startup UI: QuickType password...");
        [self unlockWithQuickTypeIdentifier];
    }
    else if ( self.mode == AutoFillOperationMode2FACodeFillQuickType ) {
        slog(@"🟢 startup UI: QuickType 2FA Code non-interactive...");
        [self unlockWithQuickTypeIdentifier];
    }
    else if ( self.mode == AutoFillOperationMode2FACodeFillManualOrQuickTypeWithUI ) {
        if ( self.credentialIdentity ) {
            slog(@"🟢 startup UI: QuickType 2FA Code interactive...");
            [self unlockWithQuickTypeIdentifier];
        }
        else {
            slog(@"🟢 startup UI: 2FA Code with manual select...");
            [self launchSingleOrRequestDatabaseSelection];
        }
    }
    else { 
        slog(@"🟢 startup UI: fallback but should be manual password select...");
        [self launchSingleOrRequestDatabaseSelection];
    }
}



- (void)launchSingleOrRequestDatabaseSelection {
    DatabasePreferences* database = [self getSingleEnabledDatabase]; 
    
    if ( database ) { 
            slog(@"AutoFill - single enabled database and Auto Proceed switched on... launching db");
            
            [self unlockDatabase:database identifier:nil transparentBio:YES];
        }
    else {
        [self initializeDatabasesListView];
    }
}

- (void)initializeDatabasesListView {
    self.currentlyPresentedNavController = [SafesListTableViewController navControllerfromStoryboard:^(BOOL userCancelled, DatabasePreferences * _Nullable database) {
        [self onSelectDatabaseCompleted:userCancelled database:database];
    }];
    
    self.currentlyPresentedNavController.presentationController.delegate = self;
    
    if ( self.presentedViewController ) { 
        [self dismissViewControllerAnimated:NO completion:^{
            [self presentViewController:self.currentlyPresentedNavController animated:NO completion:nil];
        }];
    }
    else {
        [self presentViewController:self.currentlyPresentedNavController animated:NO completion:nil];
    }
}

- (void)onSelectDatabaseCompleted:(BOOL)userCancelled
                         database:(DatabasePreferences*)database {
    if ( database ) {
        [self unlockDatabase:database identifier:nil transparentBio:NO];
    }
    else {
        [self exitWithUserCancelled:nil];
    }
}



- (void)unlockWithQuickTypeIdentifier {
    QuickTypeRecordIdentifier* identifier;
    
    if (@available(iOS 17.0, *)) {
        id<ASCredentialIdentity> credentialIdentity = self.credentialIdentity;
        identifier = [QuickTypeRecordIdentifier fromJson:credentialIdentity.recordIdentifier];
    } else {
        ASPasswordCredentialIdentity* credentialIdentity = self.credentialIdentity;
        identifier = [QuickTypeRecordIdentifier fromJson:credentialIdentity.recordIdentifier];
    }
    

    
    DatabasePreferences* database = [self getDatabaseFromQuickTypeIdentifier:identifier];
    
    if ( database ) {
        [self unlockDatabase:database identifier:identifier transparentBio:YES];
    }
    else {
        [AutoFillManager.sharedInstance clearAutoFillQuickTypeDatabase];
        
        [Alerts info:self.vcToPresentOn
               title:NSLocalizedString(@"autofill_error_unknown_item_title", @"Strongbox: Error Locating Entry")
             message:NSLocalizedString(@"autofill_error_unknown_item_message", @"Strongbox could not find this entry, it is possibly stale. Strongbox's QuickType AutoFill database has now been cleared, and so you will need to reopen your databases to refresh QuickType AutoFill.")
          completion:^{
            
            [self exitWithErrorOccurred:[Utils createNSError:@"Could not find this record in Strongbox any longer." errorCode:-1]];
        }];
    }
}

- (void)unlockDatabase:(DatabasePreferences*)safe
            identifier:(QuickTypeRecordIdentifier*)identifier
        transparentBio:(BOOL)transparentBio {
    IOSCompositeKeyDeterminer* keyDeterminer = [IOSCompositeKeyDeterminer determinerWithViewController:self.vcToPresentOn
                                                                                              database:safe
                                                                                        isAutoFillOpen:YES
                                                            transparentAutoFillBackgroundForBiometrics:transparentBio
                                                                                   biometricPreCleared:NO
                                                                                   noConvenienceUnlock:NO];
    
    [keyDeterminer getCredentials:^(GetCompositeKeyResult result, CompositeKeyFactors * _Nullable factors, BOOL fromConvenience, NSError * _Nullable error) {
        if (result == kGetCompositeKeyResultSuccess) {
            AppPreferences.sharedInstance.autoFillExitedCleanly = NO; 
            
            DatabaseUnlocker* unlocker = [DatabaseUnlocker unlockerForDatabase:safe viewController:self.vcToPresentOn forceReadOnly:NO isNativeAutoFillAppExtensionOpen:YES offlineMode:YES];
            [unlocker unlockLocalWithKey:factors keyFromConvenience:fromConvenience completion:^(UnlockDatabaseResult result, Model * _Nullable model, NSError * _Nullable error) {
                AppPreferences.sharedInstance.autoFillExitedCleanly = YES;
                
                [self onUnlockDone:result model:model identifier:identifier error:error];
            }];
        }
        else if (result == kGetCompositeKeyResultError) {
            [self messageErrorAndExit:error];
        }
        else if (result == kGetCompositeKeyResultDuressIndicated) {
            [DuressActionHelper performDuressAction:self database:safe isAutoFillOpen:NO completion:^(UnlockDatabaseResult result, Model * _Nullable model, NSError * _Nullable error) {
                [self onUnlockDone:result model:model identifier:identifier error:error];
            }];
        }
        else { 
            if ( !self.currentlyPresentedNavController ) {
                [self cancel:nil];
            }
        }
    }];
}

- (void)onUnlockDone:(UnlockDatabaseResult)result
               model:(Model * _Nullable)model
          identifier:(QuickTypeRecordIdentifier*)identifier error:(NSError * _Nullable)error {
    slog(@"AutoFill: Open Database: Model=[%@] - Error = [%@] - mode = %lu", model, error, (unsigned long)self.mode);
    
    if(result == kUnlockDatabaseResultSuccess) {
        [self onUnlockedDatabase:model quickTypeIdentifier:identifier];
    }
    else if(result == kUnlockDatabaseResultUserCancelled || result == kUnlockDatabaseResultViewDebugSyncLogRequested) {
        [self cancel:nil]; 
    }
    else if (result == kUnlockDatabaseResultIncorrectCredentials) {
        
        slog(@"INCORRECT CREDENTIALS - kUnlockDatabaseResultIncorrectCredentials");
        [self exitWithErrorOccurred:error ? error : [Utils createNSError:@"Could not open database" errorCode:-1]];
    }
    else if (result == kUnlockDatabaseResultError) {
        [self messageErrorAndExit:error];
    }
}

- (void)onUnlockedDatabase:(Model*)model
       quickTypeIdentifier:(QuickTypeRecordIdentifier*)identifier {
    if (model.metadata.autoFillConvenienceAutoUnlockTimeout == -1 && !self.withoutUserInteraction ) {
        [self onboardForAutoFillConvenienceAutoUnlock:model.metadata
                                           completion:^{
            [self continueUnlockedDatabase:model quickTypeIdentifier:identifier];
        }];
    }
    else {
        [self continueUnlockedDatabase:model quickTypeIdentifier:identifier];
    }
}

- (void)continueUnlockedDatabase:(Model*)model
             quickTypeIdentifier:(QuickTypeRecordIdentifier*)identifier {
    if ( model.metadata.autoFillConvenienceAutoUnlockTimeout > 0 ) {
        model.metadata.autoFillConvenienceAutoUnlockPassword = model.database.ckfs.password;
    }
    
    
    
    if ( self.mode == AutoFillOperationModeRegisterPasskey ) { 
        slog(@"🟢 Database successfully unlocked! Saving new passkey.");
        if (@available(iOS 17.0, *)) {
            [self createAndSaveNewPasskey:model];
        }
    }
    else if ( self.mode == AutoFillOperationModeGetPasskeyAssertionManualOrQuickTypeWithUI ) { 
        if ( identifier ) {
            slog(@"🟢 Database successfully unlocked! Finding and returning Passkey with quicktype id.");
            [self findAndReturnQuickTypeCredential:identifier model:model];
        }
        else {
            slog(@"🟢 Database successfully unlocked! Requesting passkey be manually selected for return");
            [self promptUserToSelectCredential:model selectPasskey:YES];
        }
    }
    else if ( self.mode == AutoFillOperationModeGetPasskeyAssertionQuickTypeNoUI ) { 
        slog(@"🟢 Database successfully unlocked! Finding and returning Passkey with quicktype id. (No UI mode)");
        [self findAndReturnQuickTypeCredential:identifier model:model];
    }
    else if ( self.mode == AutoFillOperationModeGetPasswordQuickType ) { 
        slog(@"🟢 Database successfully unlocked! Getting quicktype password");
        [self findAndReturnQuickTypeCredential:identifier model:model];
    }
    else if ( self.mode == AutoFillOperationMode2FACodeFillQuickType ) { 
        slog(@"🟢 Database successfully unlocked! Getting quicktype 2FA Code");
        [self findAndReturnQuickTypeCredential:identifier model:model];
    }
    else if ( self.mode == AutoFillOperationMode2FACodeFillManualOrQuickTypeWithUI ) { 
        if ( identifier ) {
            slog(@"🟢 Database successfully unlocked! Finding and returning 2FA with quicktype id.");
            [self findAndReturnQuickTypeCredential:identifier model:model];
        }
        else {
            slog(@"🟢 Database successfully unlocked! Requesting 2FA Code be manually selected for return");
            [self promptUserToSelectCredential:model selectPasskey:YES];
        }
    }
    else { 
        slog(@"🟢 Database successfully unlocked! Requesting manual selection of password.");
        [self promptUserToSelectCredential:model selectPasskey:NO];
    }
}



- (void)findAndReturnQuickTypeCredential:(QuickTypeRecordIdentifier *)identifier model:(Model *)model {
    NSUUID *uuid = [[NSUUID alloc] initWithUUIDString:identifier.nodeId];
    
    Node* node = [model.database getItemById:uuid];
    
    if ( node ) {
        if ( self.mode == AutoFillOperationModeGetPasskeyAssertionQuickTypeNoUI || self.mode == AutoFillOperationModeGetPasskeyAssertionManualOrQuickTypeWithUI ) {
            [self completePasskeyAssertionWithNode:model node:node];
        }
        else if ( self.mode == AutoFillOperationMode2FACodeFillQuickType || self.mode == AutoFillOperationMode2FACodeFillManualOrQuickTypeWithUI ) {
            [self exitWith2FACode:model item:node];
        }
        else {
            [self exitWithCredential:model item:node quickTypeIdentifier:identifier];
        }
    }
    else {
        [AutoFillManager.sharedInstance clearAutoFillQuickTypeDatabase];
        
        [Alerts info:self.vcToPresentOn
               title:@"Strongbox: Error Locating This Record"
             message:@"Strongbox could not find this record in the database any longer. It is possibly stale. Strongbox's QuickType AutoFill database has now been cleared, and so you will need to reopen your databases to refresh QuickType AutoFill."
          completion:^{
            [self exitWithErrorOccurred:model.metadata error:[Utils createNSError:@"Could not find record in database" errorCode:-1]];
        }];
    }
}

- (void)promptUserToSelectCredential:(Model *)model selectPasskey:(BOOL)selectPasskey { 
    PickCredentialsTableViewController* vc = [PickCredentialsTableViewController fromStoryboard];
    
    vc.model = model;
    vc.serviceIdentifiers = self.serviceIdentifiers;
    vc.disableCreateNew = self.mode == AutoFillOperationModeTextToInsert || self.mode == AutoFillOperationMode2FACodeFillQuickType || self.mode == AutoFillOperationMode2FACodeFillManualOrQuickTypeWithUI;
    vc.twoFactorOnly = self.mode == AutoFillOperationMode2FACodeFillQuickType || self.mode == AutoFillOperationMode2FACodeFillManualOrQuickTypeWithUI;
    vc.alsoRequestFieldSelection = self.mode == AutoFillOperationModeTextToInsert;
    
    vc.completion = ^(BOOL userCancelled, Node * _Nullable node, NSString * _Nullable username, NSString * _Nullable password) {
        if ( userCancelled ) {
            [self exitWithUserCancelled:model.metadata];
        }
        else if ( node ) { 
            if ( self.mode == AutoFillOperationModeGetPasskeyAssertionManualOrQuickTypeWithUI ) {
                slog(@"🟢 User Selected a Node and we are in passkey assertion mode...");
                [self completePasskeyAssertionWithNode:model node:node];
            }
            else if ( self.mode == AutoFillOperationModeTextToInsert ) {
                slog(@"🟢 User Selected a Node and we are in Text insertion mode...");
                [self exitWithTextToInsert:model text:password];
            }
            else if ( self.mode == AutoFillOperationMode2FACodeFillManualOrQuickTypeWithUI ) {
                slog(@"🟢 User Selected a Node and we are in 2FA Code mode...");
                [self exitWith2FACode:model item:node];
            }
            else if ( self.mode == AutoFillOperationMode2FACodeFillQuickType ) {
                slog(@"🔴 promptUserToSelect and we're in none interactive mode?!");
                [self exitWithUserCancelled:nil];
            }
            else {
                slog(@"🟢 User Selected a Node and we are in password mode... %lu", (unsigned long)self.mode);
                [self exitWithCredential:model item:node];
            }
        }
        else { 
            [self exitWithCredential:model.metadata user:username password:password];
        }
    };
    
    if ( self.currentlyPresentedNavController ) { 
        [self.currentlyPresentedNavController pushViewController:vc animated:YES];
    }
    else {
        self.currentlyPresentedNavController = [[UINavigationController alloc] initWithRootViewController:vc];
        self.currentlyPresentedNavController.presentationController.delegate = self; 
        
        [self presentViewController:self.currentlyPresentedNavController animated:YES completion:nil];
    }
}

- (void)createAndSaveNewPasskey:(Model *)model  API_AVAILABLE(ios(17.0)) {
    slog(@"🟢 createAndSaveNewPasskey...");
    
    if ( !model.isKeePass2Format ) {
        slog(@"🔴 Cannot create a Passkey in none KeePass2 format.");
        NSError* error = [Utils createNSError:@"Passkeys are unsupported this database format. Passkeys are only supported by the KeePass 2 format." errorCode:-1];
        [self exitPasskeyRegistrationRequiresKeePass2:error];
        return;
    }
    
    if ( self.currentlyPresentedNavController ) {
        [self.currentlyPresentedNavController dismissViewControllerAnimated:YES completion:nil];
    }
    
    NSError* error;
    [SwiftUIAutoFillHelper.shared registerAndSaveNewPasskey:self.passkeyCredentialRequest
                                                      model:model
                                       parentViewController:self
                                                      error:&error
                                                 completion:^(BOOL userCancelled, ASPasskeyRegistrationCredential * _Nullable response, NSError * _Nullable error) {
        slog(@"🟢 getAutoFillRegistrationCredential - userCancelled = [%hhd], error = [%@]", userCancelled, error);
        
        if ( userCancelled ) {
            [self exitWithUserCancelled:model.metadata];
        }
        else if ( error ) {
            [self exitWithErrorOccurred:model.metadata error:error];
        }
        else {
            slog(@"🟢 Got PasskeyManager response for registration = [%@]", response);
            
            if ( response ) {
                [self exitWithPasskeyRegistrationSuccess:model.metadata regCredential:response];
            }
            else {
                slog(@"🔴 Strongbox Could not complete Passkey Registration!");
                [self exitWithErrorOccurred:model.metadata error:[Utils createNSError:@"Strongbox Could not complete Passkey Registration!" errorCode:-123]];
            }
        }
    }];
    
    if ( error ) {
        slog(@"🔴 Error saving new passkey [%@]", error);
        [self exitWithErrorOccurred:model.metadata error:error];
    }
    else {
        slog(@"🟢 Registration begun ok, will wait for completion...");
    }
}

- (void)completePasskeyAssertionWithNode:(Model*)model node:(Node*)node {
    if (@available(iOS 17.0, *)) {
        NSError* error;
        ASPasskeyAssertionCredential* credential = [SwiftUIAutoFillHelper.shared getAutoFillAssertionWithRequest:self.passkeyCredentialRequest
                                                                                                         passkey:node.passkey
                                                                                                           error:&error];
        
        if ( credential ) {
            [self exitWithPasskeyAssertion:model item:node credential:credential];
        }
        else {
            [self exitWithErrorOccurred:model.metadata error:error];
        }
    }
}



- (void)messageErrorAndExit:(NSError*)error {
    [Alerts error:self.vcToPresentOn
            title:NSLocalizedString(@"open_sequence_problem_opening_title", @"There was a problem opening the database.")
            error:error
       completion:^{
        [self exitWithErrorOccurred:error ? error : [Utils createNSError:@"Could not open database" errorCode:-1]];
    }];
}

- (void)presentationControllerDidDismiss:(UIPresentationController *)presentationController {
    
    [self cancel:nil];
}

- (IBAction)cancel:(id)sender {
    [self exitWithUserCancelled:nil];
}




- (void)showLastRunCrashedMessage:(void (^)(void))completion {
    slog(@"Exit Clean = %hhd, Wrote Clean = %hhd", AppPreferences.sharedInstance.autoFillExitedCleanly, AppPreferences.sharedInstance.autoFillWroteCleanly);
    
    NSString* title = NSLocalizedString(@"autofill_did_not_close_cleanly_title", @"AutoFill Crash Occurred");
    NSString* message = NSLocalizedString(@"autofill_did_not_close_cleanly_message", @"It looks like the last time you used AutoFill you had a crash. This is usually due to a memory limitation. Please check your database file size and your Argon2 memory settings (should be <= 64MB).");
    
    [Alerts info:self.vcToPresentOn title:title message:message completion:completion];
    
    
    
    AppPreferences.sharedInstance.autoFillExitedCleanly = YES;
    AppPreferences.sharedInstance.autoFillWroteCleanly = YES;
}

- (void)exitWithUserCancelled:(DatabasePreferences*)unlockedDatabase {
    slog(@"EXIT: User Cancelled");
    
    [self commonExit:unlockedDatabase];
    
    [self.extensionContext cancelRequestWithError:[NSError errorWithDomain:ASExtensionErrorDomain code:ASExtensionErrorCodeUserCanceled userInfo:nil]];
}

- (void)exitWithUserInteractionRequired {
    slog(@"EXIT: User Interaction Required");
    [self.extensionContext cancelRequestWithError:[NSError errorWithDomain:ASExtensionErrorDomain
                                                                      code:ASExtensionErrorCodeUserInteractionRequired
                                                                  userInfo:nil]];
}

- (void)exitPasskeyRegistrationRequiresKeePass2:(NSError*)error {
    slog(@"🟢 🔴 EXIT: Error Occured [%@]", error);
    
    [Alerts info:self.vcToPresentOn
           title:NSLocalizedString(@"passkeys_unavailable_alert_title", @"Passkeys Unavailable")
         message:NSLocalizedString(@"passkeys_unavailable_alert_message", @"For technical reasons, Passkeys are unavailable in this database format. They are only supported by the KeePass 2 format. This is something you could migrate to.")
      completion:^{
        [self.extensionContext cancelRequestWithError:error];
    }];
}

- (void)exitWithErrorOccurred:(NSError*)error {
    [self exitWithErrorOccurred:nil error:error];
}

- (void)exitWithErrorOccurred:(DatabasePreferences*_Nullable)unlockedDatabase error:(NSError*)error {
    slog(@"EXIT: Error Occured [%@]", error);
    [self commonExit:unlockedDatabase];
    
    [self.extensionContext cancelRequestWithError:error];
}

- (void)exitWithCredential:(Model*)model item:(Node*)item {
    [self exitWithCredential:model item:item quickTypeIdentifier:nil];
}

- (void)exitWithCredential:(Model*)model item:(Node*)item quickTypeIdentifier:(QuickTypeRecordIdentifier*)quickTypeIdentifier {
    NSString* user = [model.database dereference:item.fields.username node:item];
    if ( user.length == 0 ) {
        user = [model.database dereference:item.fields.email node:item]; 
    }

    NSString* password = nil;
    
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
        
    [self copyTotpIfPossible:model item:item completion:^{
        [self exitWithCredential:model.metadata user:user password:password];
    }];
}

- (void)copyTotpIfPossible:(Model*)model 
                      item:(Node*)item
                completion:(void (^) (void))completion {
    NSString* totp = item.fields.otpToken ? item.fields.otpToken.password : @"";
    if ( totp.length && model.metadata.autoFillCopyTotp ) {
        
        if ( self.withoutUserInteraction ) { 
            slog(@"🟢 TOTP Copy Required - we must be interactive... retrying in interactive mode...");
            [self exitWithUserInteractionRequired];
            return;
        }
        
        slog(@"🟢 About to copy TOTP to Pasteboard...");
        [ClipboardManager.sharedInstance copyStringWithDefaultExpiration:totp];
        slog(@"🟢 Copied TOTP to Pasteboard...");
        
        completion();
    }
    else {
        completion();
    }
}

- (void)exitWithTextToInsert:(Model*)model text:(NSString*)text {
    slog(@"exitWithTextToInsert: Success");
    
    [self commonExit:model.metadata];
    
    if (@available(iOS 18.0, *)) {
        [self.extensionContext completeRequestWithTextToInsert:text completionHandler:nil]; 
    }
}

- (void)exitWith2FACode:(Model*)model item:(Node*)item {
    NSString* totp = item.fields.otpToken ? item.fields.otpToken.password : @"";
    
    slog(@"exitWith2FACode: Success");
    
    [self commonExit:model.metadata];
    
    if (@available(iOS 18.0, *)) {
        ASOneTimeCodeCredential* code = [ASOneTimeCodeCredential credentialWithCode:totp];
        [self.extensionContext completeOneTimeCodeRequestWithSelectedCredential:code completionHandler:nil];
    }
}
    
- (void)exitWithCredential:(DatabasePreferences*)database user:(NSString*)user password:(NSString*)password {
    slog(@"exitWithCredential: Success");
 
    [self commonExit:database];
    
    ASPasswordCredential *credential = [[ASPasswordCredential alloc] initWithUser:user password:password];
    [self.extensionContext completeRequestWithSelectedCredential:credential completionHandler:nil];
}

- (void)exitWithPasskeyRegistrationSuccess:(DatabasePreferences*)database regCredential:(ASPasskeyRegistrationCredential*)regCredential API_AVAILABLE(ios(17.0)){
    [self commonExit:database];

    [self.extensionContext completeRegistrationRequestWithSelectedPasskeyCredential:regCredential
                                                                  completionHandler:^(BOOL expired) {
        slog(@"🟢 Completed Passkey Registration with prepareInterfaceForPasskeyRegistration. expired = [%hhd]", expired);
    }];
}

- (void)exitWithPasskeyAssertion:(Model*)model item:(Node*)item credential:(ASPasskeyAssertionCredential*)credential API_AVAILABLE(ios(17.0)){
    __weak CredentialProviderViewController* weakSelf = self;
    
    [self copyTotpIfPossible:model item:item completion:^{
        [self commonExit:model.metadata];

        [weakSelf.extensionContext completeAssertionRequestWithSelectedPasskeyCredential:credential
                                                                   completionHandler:^(BOOL expired) {
            slog(@"🟢 Finished assertion request with expired = %hhd", expired);
        }];
    }];
}



- (void)commonExit:(DatabasePreferences*)database {
    slog(@"🟢 commonExit");
    
    AppPreferences.sharedInstance.autoFillExitedCleanly = YES;

    if ( database ) {
        database.autoFillLastUnlockedAt = NSDate.date;
    }
    
    [StrongboxFilesManager.sharedInstance deleteAllTmpDirectoryFiles];
    

}

- (DatabasePreferences*)getSingleEnabledDatabase {
    NSArray<DatabasePreferences*> *possibles = [DatabasePreferences.allDatabases filter:^BOOL(DatabasePreferences * _Nonnull obj) {
        return [self autoFillIsPossibleWithSafe:obj];
    }];
    
    return possibles.count == 1 ? possibles.firstObject : nil;
}

- (BOOL)autoFillIsPossibleWithSafe:(DatabasePreferences*)safeMetaData {
    if(!safeMetaData.autoFillEnabled) {
        return NO;
    }
        
    return [WorkingCopyManager.sharedInstance isLocalWorkingCacheAvailable:safeMetaData.uuid modified:nil];
}

- (UIViewController *)vcToPresentOn {
    return self.currentlyPresentedNavController ? self.currentlyPresentedNavController : self;
}

- (void)onboardForAutoFillConvenienceAutoUnlock:(DatabasePreferences *)database
                                     completion:(void (^)(void))completion {
    if ( !self.vcToPresentOn.presentedViewController ) { 
        [Alerts threeOptions:self.vcToPresentOn
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
