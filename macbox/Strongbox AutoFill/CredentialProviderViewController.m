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

#import "MacAlerts.h"
#import "Settings.h"
#import "DatabaseModel.h"
#import "BookmarksHelper.h"
#import "OTPToken+Generation.h"
#import "ClipboardManager.h"
#import "BiometricIdHelper.h"
#import <LocalAuthentication/LocalAuthentication.h>
#import "SelectDatabaseViewController.h"
#import "SelectCredential.h"
#import "AutoFillWormhole.h"
#import "SecretStore.h"
#import "Serializator.h"
#import "WorkingCopyManager.h"
#import "NSDate+Extensions.h"
#import "MacUrlSchemes.h"
#import "StrongboxErrorCodes.h"
#import "MacCompositeKeyDeterminer.h"
#import "DatabaseUnlocker.h"
#import "DatabasesManager.h"

#import "Strongbox_Auto_Fill-Swift.h"
#import "AutoFillWormholeHelper.h"

@interface CredentialProviderViewController ()

@property SelectDatabaseViewController* selectDbVc;

@property (nullable) NSArray<ASCredentialServiceIdentifier *>*serviceIdentifiers;
@property (nullable) MacDatabasePreferences* database;
@property (nullable) QuickTypeRecordIdentifier* quickTypeIdentifier;







@property BOOL withoutUserInteraction;
@property BOOL hasDoneCommonInit;
@property BOOL quickTypeMode;
@property id passkeyCredentialRequest;

@property BOOL requireWormhole; 
@property (weak) IBOutlet NSProgressIndicator *spinner;

@property NSSet<NSString*>* wormholeUnlockedSet;

@end

@implementation CredentialProviderViewController

- (void)commonInit {
    if ( !self.hasDoneCommonInit ) {
        slog(@"🟢 AutoFill::commonInit");
        self.hasDoneCommonInit = YES;
        
        [DatabasesManager.sharedInstance forceReload];
    }
    else {
        slog(@"🟢 AutoFill::commonInit - Already Inited");
    }
}




- (void)provideCredentialWithoutUserInteractionForIdentity:(ASPasswordCredentialIdentity *)credentialIdentity {
    [self commonInit];

    slog(@"🟢 AutoFill: provideCredentialWithoutUserInteractionForIdentity [%@]", credentialIdentity);

    self.quickTypeMode = YES;
    self.withoutUserInteraction = YES;
    
    BOOL pro = Settings.sharedInstance.isPro;

    if ( !pro ) {
        [self exitWithUserCancelled:nil];
        return;
    }

    QuickTypeRecordIdentifier* identifier = [QuickTypeRecordIdentifier fromJson:credentialIdentity.recordIdentifier];
    slog(@"Checking wormhole to see if Main App can provide credentials immediately...");

    if ( identifier ) {
        MacDatabasePreferences* database = [MacDatabasePreferences fromUuid:identifier.databaseId];

        if ( database && database.autoFillEnabled && database.autoFillEnabled && database.quickTypeEnabled ) {
            [self doWormholePasswordFill:identifier];
            return;
        }
    }

    [self exitWithUserInteractionRequired];
}

- (void)provideCredentialWithoutUserInteractionForRequest:(id<ASCredentialRequest>)credentialRequest {
    [self commonInit];

    slog(@"🟢 provideCredentialWithoutUserInteractionForRequest [%@]", credentialRequest);
    
    self.withoutUserInteraction = YES;
    self.quickTypeMode = YES;
    
    if ( credentialRequest.type == ASCredentialRequestTypePasskeyAssertion ) {
        BOOL pro = Settings.sharedInstance.isPro;
        
        if ( !pro ) {
            [self exitWithUserCancelled:nil];
            return;
        }
        
        self.passkeyCredentialRequest = credentialRequest;
        id<ASCredentialIdentity> credentialIdentity = credentialRequest.credentialIdentity;
        
        QuickTypeRecordIdentifier* identifier = [QuickTypeRecordIdentifier fromJson:credentialIdentity.recordIdentifier];
        slog(@"Checking wormhole to see if Main App can provide credentials immediately...");
        
        if ( identifier ) {
            MacDatabasePreferences* database = [MacDatabasePreferences fromUuid:identifier.databaseId];
            
            if ( database && database.autoFillEnabled && database.autoFillEnabled ) {
                [self doWormholePasskeyAttestation:identifier];
                return;
            }
        }
        
        [self exitWithUserInteractionRequired];
    }
    else {
        [self provideCredentialWithoutUserInteractionForIdentity:(ASPasswordCredentialIdentity*)credentialRequest.credentialIdentity];
    }
}

- (void)doWormholePasskeyAttestation:(QuickTypeRecordIdentifier*)identifier {
    if (@available(macOS 14.0, *)) {
        ASPasskeyCredentialRequest* request = self.passkeyCredentialRequest;
        
        [AutoFillWormholeHelper.sharedInstance postWormholeMessage:kAutoFillWormholePasskeyAssertionRequestId
                                                        responseId:kAutoFillWormholePasskeyAssertionResponseId
                                                           message:@{ @"id" : [identifier toJson],
                                                                      @"clientDataHash" : request.clientDataHash }
                                                        completion:^(BOOL success, NSDictionary<NSString *,id> * _Nullable response) {
            if ( success ) {

                NSData* userHandle = response[@"userHandle"];
                NSString* relyingParty = response[@"relyingParty"];
                NSData* credentialID = response[@"credentialID"];
                NSData* signature = response[@"signature"];
                NSData* authenticatorData = response[@"authenticatorData"];
                
                ASPasskeyAssertionCredential* credential = [ASPasskeyAssertionCredential credentialWithUserHandle:userHandle
                                                                                                     relyingParty:relyingParty
                                                                                                        signature:signature
                                                                                                   clientDataHash:request.clientDataHash
                                                                                                authenticatorData:authenticatorData
                                                                                                     credentialID:credentialID];
                
                MacDatabasePreferences* metadata = [MacDatabasePreferences fromUuid:identifier.databaseId];
                [self exitWithPasskeyAssertion:metadata credential:credential totp:nil]; 
            }
            else {
                [self exitWithUserInteractionRequired];
            }
        }];
    }
}

- (void)doWormholePasswordFill:(QuickTypeRecordIdentifier*)identifier {
    [AutoFillWormholeHelper.sharedInstance postWormholeMessage:kAutoFillWormholeQuickTypeRequestId
                                                    responseId:kAutoFillWormholeQuickTypeResponseId
                                                       message:@{ @"id" : [identifier toJson] }
                                                    completion:^(BOOL success, NSDictionary<NSString *,id> * _Nullable message) {
        if ( success ) {
            MacDatabasePreferences* metadata = [MacDatabasePreferences fromUuid:identifier.databaseId];
            
            NSString* secretStoreId = message[@"secret-store-id"];
            
            NSDictionary* payload = [SecretStore.sharedInstance getSecureObject:secretStoreId];
            [SecretStore.sharedInstance deleteSecureItem:secretStoreId];
            
            NSString* username = payload[@"user"];
            NSString* password = payload[@"password"];

            
            if ( username && password ) {
                [self exitWithCredential:metadata username:username password:password totp:nil];
            }
            else {
                slog(@"🔴 Successful wormhole quicktype request but nothing in secret store? => UI");
                [self exitWithUserInteractionRequired];
            }
        }
        else {
            [self exitWithUserInteractionRequired];
        }
    }];
}




- (void)prepareInterfaceForPasskeyRegistration:(id<ASCredentialRequest>)registrationRequest {
    [self commonInit];
    
    slog(@"🟢 prepareInterfaceForPasskeyRegistration [%@]", registrationRequest);
    
    self.quickTypeMode = NO;
    self.requireWormhole = YES;
    
    self.passkeyCredentialRequest = registrationRequest;
}




- (void)prepareInterfaceToProvideCredentialForRequest:(id<ASCredentialRequest>)credentialRequest {
    [self commonInit];
    
    slog(@"🟢 prepareInterfaceToProvideCredentialForRequest called with [%@]", credentialRequest);
    
    BOOL pro = Settings.sharedInstance.isPro;
    
    if ( !pro ) {
        [self exitWithUserCancelled:nil];
        return;
    }

    self.quickTypeMode = YES;

    if ( credentialRequest.type == ASCredentialRequestTypePasskeyAssertion ) {
        self.passkeyCredentialRequest = credentialRequest;
        
        id<ASCredentialIdentity> credentialIdentity = credentialRequest.credentialIdentity;
        
        QuickTypeRecordIdentifier* identifier = [QuickTypeRecordIdentifier fromJson:credentialIdentity.recordIdentifier];
        [self initializeQuickTypeWithUI:identifier];
    }
    else {
        [self prepareInterfaceToProvideCredentialForIdentity:(ASPasswordCredentialIdentity*)credentialRequest.credentialIdentity];
    }
}

- (void)prepareInterfaceToProvideCredentialForIdentity:(ASPasswordCredentialIdentity *)credentialIdentity {
    [self commonInit];
    
    slog(@"AutoFill: prepareInterfaceToProvideCredentialForIdentity [%@]", credentialIdentity);
    
    self.quickTypeMode = YES;
    
    QuickTypeRecordIdentifier* identifier = [QuickTypeRecordIdentifier fromJson:credentialIdentity.recordIdentifier];
    
    [self initializeQuickTypeWithUI:identifier];
}

- (void)initializeQuickTypeWithUI:(QuickTypeRecordIdentifier*)identifier {
    
    
    if ( identifier ) {
        MacDatabasePreferences* safe = [MacDatabasePreferences fromUuid:identifier.databaseId];
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.15 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            if( safe ) {
                [self unlockDatabase:safe 
                 quickTypeIdentifier:identifier
                  serviceIdentifiers:nil];
            }
            else {
                [AutoFillManager.sharedInstance clearAutoFillQuickTypeDatabase];
                




                    [self exitWithErrorOccurred:[Utils createNSError:@"Could not find this database in Strongbox any longer." errorCode:-1]];

            }
        });
    }
    else {
        [AutoFillManager.sharedInstance clearAutoFillQuickTypeDatabase];
        




            [self exitWithErrorOccurred:[Utils createNSError:@"Could not find this database in Strongbox any longer." errorCode:-1]];

    }
}




- (void)prepareCredentialListForServiceIdentifiers:(NSArray<ASCredentialServiceIdentifier *> *)serviceIdentifiers {
    [self commonInit];
    

    slog(@"🟢 prepareCredentialListForServiceIdentifiers");
    
    self.quickTypeMode = NO;
    
    self.serviceIdentifiers = serviceIdentifiers;
}



- (void)viewDidLoad {
    [super viewDidLoad];
    
    slog(@"🟢 viewDidLoad");
    
    [self commonInit];
}

- (void)viewWillAppear {
    [super viewWillAppear];

    [self.spinner startAnimation:nil];
 
    slog(@"🟢 viewWillAppear - sheet parent = [%@], presentingViewController = [%@], window = [%@]", self.view.window.sheetParent, self.presentingViewController, self.view.window);

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.15 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self delayedStartup];
    });
}

- (void)delayedStartup {
    slog(@"🟢 delayedStartup - sheet parent = [%@], presentingViewController = [%@], window = [%@]", self.view.window.sheetParent, self.presentingViewController, self.view.window);
    
    if ( !self.quickTypeMode ) {
        [self startupWithUI];
    }
    else {
        slog(@"🟢 delayedStartup - quickType mode - NOP");
        
        
        
        
        
        
    }
}

- (void)startupWithUI {
    slog(@"🟢 ✅ startupWithUI");
    
    [AutoFillWormholeHelper.sharedInstance postWormholeMessage:kAutoFillWormholePingRequestId
                                                    responseId:kAutoFillWormholePingResponseId
                                                       message:@{}
                                                    completion:^(BOOL success, NSDictionary<NSString *,id> * _Nullable response) {
        if ( success ) {
            NSArray<NSString*>* unlockedDatabases = response[@"unlockedDatabases"];
            
            slog(@"AutoFill-Wormhole: Got Database PING Response Message [%@] are unlocked", unlockedDatabases);
            
            self.wormholeUnlockedSet = [NSSet setWithArray:unlockedDatabases];
            
            slog(@"🟢 startupWithUI - Wormhole Ping Successful...");
            
            [self launchSingleOrRequestDatabaseSelection];
        }
        else if ( self.requireWormhole ) {
            [self exitPasskeyRegistrationRequiresMainApp:[Utils createNSError:@"Strongbox must be running to register a new Passkey.\n\nMake sure Strongbox is running in the background." errorCode:-1]];
        }
        else {
            [self launchSingleOrRequestDatabaseSelection];
        }
    }];
}

- (void)launchSingleOrRequestDatabaseSelection {
    slog(@"✅ launchSingleOrRequestDatabaseSelection");
    
    NSArray<MacDatabasePreferences*> *databases = [MacDatabasePreferences filteredDatabases:^BOOL(MacDatabasePreferences * _Nonnull database) {
        return database.autoFillEnabled;
    }];
    
    if ( databases.count == 1 ) {
        slog(@"Single Database Launching...");
        
        MacDatabasePreferences* database = databases.firstObject;
        __weak CredentialProviderViewController* weakSelf = self;
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [weakSelf unlockDatabase:database 
                 quickTypeIdentifier:nil
                  serviceIdentifiers:weakSelf.serviceIdentifiers];
        });
    }
    else {
        [self requestDatabaseSelection];
    }
}

- (void)requestDatabaseSelection {
    dispatch_async(dispatch_get_main_queue(), ^{
        slog(@"✅ requestDatabaseSelectionWithUnlockedSet - [%@]", self.selectDbVc);
        
        self.selectDbVc = [SelectDatabaseViewController fromStoryboard];
        self.selectDbVc.autoFillMode = YES;
        self.selectDbVc.unlockedDatabases = self.wormholeUnlockedSet;
        
        __weak CredentialProviderViewController* weakSelf = self;
        self.selectDbVc.onDone = ^(BOOL userCancelled, MacDatabasePreferences * _Nonnull database) {
            if (userCancelled) {
                [weakSelf exitWithUserCancelled:nil];
            }
            else {
                [weakSelf unlockDatabase:database
                     quickTypeIdentifier:nil
                      serviceIdentifiers:weakSelf.serviceIdentifiers];
            }
        };
        
        if(!self.selectDbVc) {
            [self exitWithErrorOccurred:[Utils createNSError:@"There was an error loading the Safes List View" errorCode:-1]];
        }
        else {
            [self presentViewControllerAsSheet:self.selectDbVc];
        }
    });
}




- (void)unlockDatabase:(MacDatabasePreferences*)database
   quickTypeIdentifier:(QuickTypeRecordIdentifier*_Nullable)quickTypeIdentifier
    serviceIdentifiers:(NSArray<ASCredentialServiceIdentifier *> *)serviceIdentifiers {

    
    StorageProvider provider = database.storageProvider;
    BOOL sftpOrDav = provider == kSFTP || provider == kWebDAV;
    
    if ( sftpOrDav && !Settings.sharedInstance.isPro ) {
        [MacAlerts info:NSLocalizedString(@"mac_non_file_database_pro_message", @"This database can only be unlocked by Strongbox Pro because it is stored via SFTP or WebDAV.\n\nPlease Upgrade.")
        informativeText:NSLocalizedString(@"mac_non_file_database_pro_message", @"This database can only be unlocked by Strongbox Pro because it is stored via SFTP or WebDAV.\n\nPlease Upgrade.")
                 window:self.view.window
             completion:^{
            [self exitWithUserCancelled:nil];
        }];
        return;
    }
    
    if ( !database.autoFillEnabled ) {
        [MacAlerts info:NSLocalizedString(@"autofill_vc_item_subtitle_disabled", @"AutoFill Disabled")
        informativeText:NSLocalizedString(@"autofill_vc_item_subtitle_disabled", @"AutoFill Disabled")
                 window:self.view.window
             completion:^{
            [self exitWithUserCancelled:nil];
        }];
        
        return;
    }
    
    self.database = database;
    self.serviceIdentifiers = serviceIdentifiers;
    self.quickTypeIdentifier = quickTypeIdentifier;
    
    BOOL keyFileNotSetButRequired = self.database.keyFileBookmark.length && !self.database.autoFillKeyFileBookmark.length;
    if ( keyFileNotSetButRequired ) {
        slog(@"🟢 Unlock Database: keyFileNotSetButRequired Showing Manual Unlock to allow user to select...");
        [self manualUnlockDatabase];
        return;
    }
    else {
        [self tryConvenienceOrWormholeUnlock];
    }
}

- (void)tryConvenienceOrWormholeUnlock {
    slog(@"🟢 AUTOFILL: tryConvenienceOrWormholeUnlock ENTER");
    
    if ( !self.wormholeUnlockedSet ) { 
        [AutoFillWormholeHelper.sharedInstance postWormholeMessage:kAutoFillWormholePingRequestId
                                                        responseId:kAutoFillWormholePingResponseId
                                                           message:@{}
                                                        completion:^(BOOL success, NSDictionary<NSString *,id> * _Nullable response) {
            if ( success ) {
                NSArray<NSString*>* unlockedDatabases = response[@"unlockedDatabases"];
                
                slog(@"🟢 AutoFill-Wormhole: Got Database PING Response Message [%@] are unlocked", unlockedDatabases);
                
                self.wormholeUnlockedSet = [NSSet setWithArray:unlockedDatabases];
            }

            [self tryConvenienceOrWormholeUnlockWithUnlockedSet];
        }];
    }
    else {
        [self tryConvenienceOrWormholeUnlockWithUnlockedSet];
    }
}

- (void)tryConvenienceOrWormholeUnlockWithUnlockedSet {
    slog(@"🟢 AUTOFILL: tryConvenienceOrWormholeUnlockWithUnlockedSet ENTER");
    
    NSString* conveniencePassword = self.database.conveniencePassword ? self.database.conveniencePassword : self.database.autoFillConvenienceAutoUnlockPassword;
    
    if ( conveniencePassword &&
        ((self.wormholeUnlockedSet && [self.wormholeUnlockedSet containsObject:self.database.uuid]) ||
         [self isWithinAutoFillConvenienceAutoUnlockTime:self.database])) {
        slog(@"🟢 AUTOFILL: Database is already open in main App, or within convenience timeout - convenience unlock possible - express ...");

        [self unlock:conveniencePassword];
    }
    else {
        slog(@"🟢 AUTOFILL: Database is not already open or within convenience timeout will try wormhole unlock...");
        
        [AutoFillWormholeHelper.sharedInstance postWormholeMessage:kAutoFillWormholeConvUnlockRequestId
                                                        responseId:kAutoFillWormholeConvUnlockResponseId
                                                           message:@{ @"database-id" : self.database.uuid }
                                                        completion:^(BOOL success, NSDictionary<NSString *,id> * _Nullable response) {
            if ( success ) {
                NSString* secretStoreId = response[@"secret-store-id"];
                
                if ( secretStoreId ) {

                    
                    NSString* convUnlock = [SecretStore.sharedInstance getSecureObject:secretStoreId];
                    
                    if ( convUnlock ) {
                        [SecretStore.sharedInstance deleteSecureItem:secretStoreId];
                    }
                    else {
                        slog(@"🟢 🔴 Could not find stored SE secret!?!");
                    }
                    
                    [self unlock:convUnlock];
                }
                else {

                    [self unlock:nil]; 
                }
            }
            else {
                [self unlock:nil]; 
            }
        }];
    }
}

- (void)unlock:(NSString*)conveniencePassword {
    if ( conveniencePassword ) {
        slog(@"🟢 Unlocking with convenience password");
        [self unlockWithExplicitPassword:conveniencePassword];
    }
    else {
        slog(@"🟢 Could not unlock with convenience/wormhole... regular sequence");
        [self doRegularUnlockSequence];
    }
}

- (void)manualUnlockDatabase {

    
    MacCompositeKeyDeterminer* det = [MacCompositeKeyDeterminer determinerWithViewController:self
                                                                                    database:self.database
                                                            isNativeAutoFillAppExtensionOpen:YES
                                                                     isAutoFillQuickTypeOpen:self.quickTypeMode];
    
    [det getCkfsManually:^(GetCompositeKeyResult result, CompositeKeyFactors * _Nullable factors, BOOL fromConvenience, NSError * _Nullable error) {
        [self handleGetCkfsResult:result factors:factors fromConvenience:fromConvenience error:error];
    }];
}

- (void)doRegularUnlockSequence {
    slog(@"🟢 doRegularUnlockSequence ENTER");
    
    MacCompositeKeyDeterminer* det = [MacCompositeKeyDeterminer determinerWithViewController:self
                                                                                    database:self.database
                                                            isNativeAutoFillAppExtensionOpen:YES
                                                                     isAutoFillQuickTypeOpen:self.quickTypeMode];
    
    [det getCkfs:^(GetCompositeKeyResult result, CompositeKeyFactors * _Nullable factors, BOOL fromConvenience, NSError * _Nullable error) {
        [self handleGetCkfsResult:result factors:factors fromConvenience:fromConvenience error:error];
    }];
}

- (void)unlockWithExplicitPassword:(NSString*)password {
    slog(@"AUTOFILL: unlockWithPassword ENTER");
    
    MacCompositeKeyDeterminer* det = [MacCompositeKeyDeterminer determinerWithViewController:self
                                                                                    database:self.database
                                                            isNativeAutoFillAppExtensionOpen:YES
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
    slog(@"🟢 AutoFill -> handleGetCkfsResult [%@] - Error = [%@] - Convenience = [%hhd]", result == kGetCompositeKeyResultSuccess ? @"Succeeded" : @"Failed", error, fromConvenience);
    
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

        [self exitWithUserCancelled:nil];
    }
}



- (void)unlockDatabaseWithCkf:(CompositeKeyFactors*)ckf
          isConvenienceUnlock:(BOOL)isConvenienceUnlock {
    DatabaseUnlocker *unlocker = [DatabaseUnlocker unlockerForDatabase:self.database
                                                        viewController:self
                                                         forceReadOnly:NO
                                      isNativeAutoFillAppExtensionOpen:YES
                                                           offlineMode:NO];
    
    unlocker.noProgressSpinner = YES;
    
    [unlocker unlockLocalWithKey:ckf
              keyFromConvenience:isConvenienceUnlock
                      completion:^(UnlockDatabaseResult result, Model * _Nullable model, NSError * _Nullable error) {
        slog(@"unlockLocalWithKey => [%lu](%@) - error = [%@]", result, result == kUnlockDatabaseResultSuccess ? @"Success" : @"Not Successful", error);
        
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
        






            [self continueUnlockedDatabase:model];

    });
}

- (void)continueUnlockedDatabase:(Model*)model {
    slog(@"🟢 CredentialProviderViewController::continueUnlockedDatabase");
    
    if ( self.database.autoFillConvenienceAutoUnlockTimeout > 0 ) {
        self.database.autoFillConvenienceAutoUnlockPassword = model.database.ckfs.password;
        [self markLastUnlockedAtTime:self.database];
    }
    
    if ( self.quickTypeIdentifier ) {
        if ( self.passkeyCredentialRequest ) {
            [self completePasskeyAssertionWithNode:model];
        }
        else {
            [self autoFillWithQuickType:model];
        }
    }
    else {
        if ( self.passkeyCredentialRequest ) {
            if (@available(macOS 14.0, *)) {
                [self createAndSaveNewPasskey:model];
            }
        }
        else { 
            [self presentCredentialSelector:model];
        }
    }
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
        if ( user.length == 0 ) {
            user = [model.database dereference:node.fields.email node:node]; 
        }

        NSString* totp = node.fields.otpToken ? node.fields.otpToken.password : @"";
        
        password = password ? password : @"";
        [self exitWithCredential:self.database username:user password:password totp:totp];
    }
    else {
        [AutoFillManager.sharedInstance clearAutoFillQuickTypeDatabase];
        




            [self exitWithErrorOccurred:[Utils createNSError:@"Could not find record in database" errorCode:-1]];

    }
}

static NSString *getCompanyOrOrganisationNameFromDomain(NSString* domain) {
    if(!domain.length) {
        return domain;
    }
    
    NSArray<NSString*> *parts = [domain componentsSeparatedByString:@"."];
    
    NSString *searchTerm = parts.count ? parts[0] : domain;
    return searchTerm;
}

- (void)presentCredentialSelector:(Model*)model {

    
    SelectCredential* vc = [[SelectCredential alloc] initWithNibName:@"SelectCredential" bundle:nil];
    vc.model = model;
    vc.serviceIdentifiers = self.serviceIdentifiers;
    vc.onDone = ^(BOOL userCancelled, BOOL createNew, NSString * _Nullable username, NSString * _Nullable password, NSString * _Nullable totp) {
        if (userCancelled) {
            [self exitWithUserCancelled:self.database];
        }
        else if ( createNew ) {
            NSError* error;
            if (@available(macOS 13.0, *)) {
                NSString* suggestedTitle = nil;
                NSString* suggestedUrl = nil;
                
                ASCredentialServiceIdentifier *serviceId = [self.serviceIdentifiers firstObject];
                if(serviceId) {

                        NSString* bar = [BrowserAutoFillManager extractPSLDomainFromUrlWithUrl:serviceId.identifier];
                        suggestedUrl = [NSString stringWithFormat:@"https:
                        
                        NSString* foo = getCompanyOrOrganisationNameFromDomain(bar);
                        suggestedTitle = foo.length ? [foo capitalizedString] : foo;







                }
                
                [SwiftUIAutoFillHelper.shared createAndSaveNewEntryWithModel:model
                                                                initialTitle:suggestedTitle 
                                                                  initialUrl:suggestedUrl
                                                        parentViewController:self
                                                                       error:&error
                                                                  completion:^(BOOL userCancelled, Node* node, NSError * _Nullable error) {
                    [self onCreateNewDialogDone:model userCancelled:userCancelled node:node error:error];
                }];
            }
            else {
                [self exitWithUserCancelled:model.metadata]; 
                return;
            }
            
            if ( error ) {
                slog(@"🔴 Error saving new entry [%@]", error);
                [self exitWithErrorOccurred:error];
            }
            else {
                slog(@"🟢 Create New Dialog begun ok, will wait for completion...");
            }
        }
        else {
            [self exitWithCredential:self.database username:username password:password totp:totp];
        }
    };
    
    [self presentViewControllerAsSheet:vc];
}

- (void)onCreateNewDialogDone:(Model*)model
                userCancelled:(BOOL)userCancelled
                         node:(Node*)node
                        error:(NSError*)error {
    [self dismissAllPresentedViewControllers];
    
    if ( userCancelled ) {
        [self exitWithUserCancelled:model.metadata];
    }
    else if ( error ) {
        [self exitWithErrorOccurred:error];
    }
    else {
        [self initiatiateMainAppSyncAfterAFWrite:model 
                                      completion:^(BOOL success) {
            if ( success ) {
                slog(@"🟢 initiatiateMainAppSyncAfterAFWrite Completion");
                
                [self exitWithCredential:model.metadata username:node.fields.username password:node.fields.password totp:nil];
            }
            else {
                slog(@"🟢 🔴 initiatiateMainAppSyncAfterAFWrite Completion not successful");
                
                [MacAlerts info:NSLocalizedString(@"generic_error", @"Error")
                informativeText:NSLocalizedString(@"entry_saved_but_could_not_reload", @"Your new entry was successfully created and saved to your database but Strongbox could not initiate a reload.\n\nYou should try to reload your database now.")
                         window:self.view.window
                     completion:^{
                    [self exitWithCredential:model.metadata username:node.fields.username password:node.fields.password totp:nil];
                }];
            }
        }];
    }
}



- (void)dismissAllPresentedViewControllers {
    for ( NSViewController* vc in self.presentedViewControllers ) {
        [Utils dismissViewControllerCorrectly:vc];
    }
}

- (void)createAndSaveNewPasskey:(Model*)model API_AVAILABLE(macos(14.0)) {
    slog(@"🟢 AUTOFILL: createAndSaveNewPasskey ENTER");
    
    if ( !model.isKeePass2Format ) {
        slog(@"🔴 Cannot create a Passkey in none KeePass2 format.");
        NSError* error = [Utils createNSError:@"Passkeys are unsupported this database format. Passkeys are only supported by the KeePass 2 format." errorCode:-1];
        [self exitPasskeyRegistrationRequiresKeePass2:error];
        return;
    }
    
    NSError* error;
    [SwiftUIAutoFillHelper.shared registerAndSaveNewPasskey:self.passkeyCredentialRequest
                                                      model:model
                                       parentViewController:self
                                                      error:&error
                                                 completion:^(BOOL userCancelled, ASPasskeyRegistrationCredential * _Nullable response, NSError * _Nullable error) {
        slog(@"🟢 getAutoFillRegistrationCredential - userCancelled = [%hhd], error = [%@]", userCancelled, error);
        
        
        
        
        [self dismissAllPresentedViewControllers];





        
        if ( userCancelled ) {
            [self exitWithUserCancelled:model.metadata];
        }
        else if ( error ) {
            [self exitWithErrorOccurred:error];
        }
        else {
            slog(@"🟢 Got PasskeyManager response for registration = [%@]", response);
            
            if ( response ) {
                [self initiatiateMainAppSyncAfterAFWrite:model 
                                              completion:^(BOOL success) {
                    if ( success ) {

                        
                        [self exitWithPasskeyRegistrationSuccess:model.metadata regCredential:response];
                    }
                    else {

                        
                        [MacAlerts info:NSLocalizedString(@"generic_error", @"Error")
                        informativeText:NSLocalizedString(@"passkey_saved_but_could_not_reload", @"Your passkey was successfully created and saved to your database but Strongbox could not initiate a reload.\n\nYou should try to reload your database now.")
                                 window:self.view.window
                             completion:^{
                            [self exitWithPasskeyRegistrationSuccess:model.metadata regCredential:response];
                        }];
                    }
                }];
            }
            else {

                [self exitWithErrorOccurred:[Utils createNSError:@"Strongbox Could not complete Passkey Registration!" errorCode:-123]];
            }
        }
    }];
    
    if ( error ) {
        slog(@"🔴 Error saving new passkey [%@]", error);
        [self exitWithErrorOccurred:error];
    }
    else {
        slog(@"🟢 Registration begun ok, will wait for completion...");
    }
}

- (void)initiatiateMainAppSyncAfterAFWrite:(Model*)model completion:(void (^)(BOOL))completion {

    
    [DatabasesManager.sharedInstance forceSerialize]; 
                              
    
    
    [AutoFillWormholeHelper.sharedInstance postWormholeMessage:kAutoFillWormholeSyncRequestId
                                                    responseId:kAutoFillWormholeSyncResponseId
                                                       message:@{ @"database-id" : self.database.uuid }
                                                    completion:^(BOOL success, NSDictionary<NSString *,id> * _Nullable response) {
        if ( success ) {
            completion(YES);
        }
        else {
            completion(NO);
        }
    }];
}

- (void)completePasskeyAssertionWithNode:(Model*)model {

    
    NSUUID* uuid = [[NSUUID alloc] initWithUUIDString:self.quickTypeIdentifier.nodeId];
    Node* node = [model getItemById:uuid];
    
    if(node) {
        if (@available(macOS 14.0, *)) {
            NSError* error;
            ASPasskeyAssertionCredential* credential = [SwiftUIAutoFillHelper.shared getAutoFillAssertionWithRequest:self.passkeyCredentialRequest
                                                                                                             passkey:node.passkey
                                                                                                               error:&error];
            
            if ( credential ) {
                NSString* totp = node.fields.otpToken ? node.fields.otpToken.password : @"";
                
                [self exitWithPasskeyAssertion:model.metadata credential:credential totp:totp];
            }
            else {
                [self exitWithErrorOccurred:error];
            }
        }
    }
    else {
        [AutoFillManager.sharedInstance clearAutoFillQuickTypeDatabase];

        
        




            [self exitWithErrorOccurred:[Utils createNSError:@"Could not find record in database" errorCode:-1]];

    }
    
}



- (void)markLastUnlockedAtTime:(MacDatabasePreferences*)database {
    database.autoFillLastUnlockedAt = NSDate.date;
}

- (BOOL)isWithinAutoFillConvenienceAutoUnlockTime:(MacDatabasePreferences*)database {
    BOOL isWithinAutoFillConvenienceAutoUnlockTime = NO;
    
    
    
    if ( database.autoFillLastUnlockedAt != nil && database.autoFillConvenienceAutoUnlockTimeout > 0 ) {
        isWithinAutoFillConvenienceAutoUnlockTime = ![database.autoFillLastUnlockedAt isMoreThanXSecondsAgo:database.autoFillConvenienceAutoUnlockTimeout];
        
    }
    
    return isWithinAutoFillConvenienceAutoUnlockTime;
}

- (IBAction)onCancel:(id)sender {
    [self exitWithUserCancelled:nil];
}

- (void)copyTotpIfPossible:(MacDatabasePreferences*)unlockedDatabase 
                      totp:(NSString*)totp
                completion:(void (^) (void))completion {
    BOOL pro = Settings.sharedInstance.isPro;
    
    if (!pro) {
        
        
        if ( self.view && self.view.window && !self.withoutUserInteraction ) {
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
    
    if ( totp.length && unlockedDatabase.autoFillCopyTotp ) {
        if ( self.withoutUserInteraction ) {
            
            
            slog(@"🟢 TOTP Copy Required - we must be interactive... retrying in interactive mode...");
            [self exitWithUserInteractionRequired];
            return;
        }
        
        [ClipboardManager.sharedInstance copyConcealedString:totp];
        slog(@"🟢 Copied TOTP to Clipboard...");
        
        






















    }
    
    completion();
}




- (void)exitWithUserCancelled:(MacDatabasePreferences*)unlockedDatabase {

    
    if ( unlockedDatabase ) {
        [self markLastUnlockedAtTime:unlockedDatabase];
    }
    [self notifyMainAppAutoFillExited];
    
    [self.extensionContext cancelRequestWithError:[NSError errorWithDomain:ASExtensionErrorDomain code:ASExtensionErrorCodeUserCanceled userInfo:nil]];
}

- (void)exitWithUserInteractionRequired {
    [self notifyMainAppAutoFillExited];
    
    slog(@"🟢 EXIT: User Interaction Required");
    
    [self.extensionContext cancelRequestWithError:[NSError errorWithDomain:ASExtensionErrorDomain
                                                                      code:ASExtensionErrorCodeUserInteractionRequired
                                                                  userInfo:nil]];
}

- (void)exitPasskeyRegistrationRequiresMainApp:(NSError*)error {
    slog(@"🟢 🔴 EXIT: exitPasskeyRegistrationRequiresMainApp [%@]", error);
    
    [MacAlerts info:NSLocalizedString(@"autofill_sb_not_running_title", @"Strongbox Not Running")
    informativeText:NSLocalizedString(@"autofill_sb_not_running_message", @"Strongbox must be running to register a new Passkey.\n\nMake sure Strongbox is running in the background.")
              window:self.view.window
          completion:^{
        [self notifyMainAppAutoFillExited];
        [self.extensionContext cancelRequestWithError:error];
    }];
}

- (void)exitPasskeyRegistrationRequiresKeePass2:(NSError*)error {
    slog(@"🟢 🔴 EXIT: exitPasskeyRegistrationRequiresKeePass2 [%@]", error);
    
    [MacAlerts info:NSLocalizedString(@"passkeys_unavailable_alert_title", @"Passkeys Unavailable")
    informativeText:NSLocalizedString(@"passkeys_unavailable_alert_message", @"For technical reasons, Passkeys are unavailable in this database format. They are only supported by the KeePass 2 format. This is something you could migrate to.")
              window:self.view.window
          completion:^{
        [self notifyMainAppAutoFillExited];
        [self.extensionContext cancelRequestWithError:error];
    }];
}

- (void)exitWithErrorOccurred:(NSError*)error {
    slog(@"🟢 🔴 EXIT: Error Occured [%@]", error);
    
    if ( !self.withoutUserInteraction ) {
        [MacAlerts error:error
                  window:self.view.window
              completion:^{
            [self notifyMainAppAutoFillExited];
            [self.extensionContext cancelRequestWithError:error];
        }];
    }
    else {
        [self notifyMainAppAutoFillExited];
        [self.extensionContext cancelRequestWithError:error];
    }
}

- (void)exitWithCredential:(MacDatabasePreferences*)unlockedDatabase username:(NSString*)username password:(NSString*)password totp:(NSString*)totp {
    [self markLastUnlockedAtTime:unlockedDatabase];
    
    __weak CredentialProviderViewController* weakSelf = self;
    
    [self copyTotpIfPossible:unlockedDatabase totp:totp completion:^{
        ASPasswordCredential *credential = [[ASPasswordCredential alloc] initWithUser:username password:password];
        
        slog(@"🟢 EXIT: completeRequestWithSelectedCredential - Success");
       
        [self notifyMainAppAutoFillExited];
        [weakSelf.extensionContext completeRequestWithSelectedCredential:credential completionHandler:nil];
    }];
}



- (void)exitWithPasskeyRegistrationSuccess:(MacDatabasePreferences*)database
                             regCredential:(ASPasskeyRegistrationCredential*)regCredential API_AVAILABLE(macos(14.0)) {
    slog(@"🟢 EXIT: exitWithPasskeyRegistrationSuccess...");
    
    [self markLastUnlockedAtTime:database];
    
    [self notifyMainAppAutoFillExited];
    
    [self.extensionContext completeRegistrationRequestWithSelectedPasskeyCredential:regCredential
                                                                  completionHandler:^(BOOL expired) {
        slog(@"🟢 Completed Passkey Registration with prepareInterfaceForPasskeyRegistration. expired = [%hhd]", expired);
    }];
}

- (void)exitWithPasskeyAssertion:(MacDatabasePreferences*)database
                      credential:(ASPasskeyAssertionCredential*)credential
                            totp:(NSString*)totp API_AVAILABLE(macos(14.0)) {
    slog(@"🟢 EXIT: exitWithPasskeyAssertion...");
    
    __weak CredentialProviderViewController* weakSelf = self;
    
    if ( totp.length ) {
        [self copyTotpIfPossible:database
                            totp:totp
                      completion:^{
            [weakSelf continueExitWithPasskeyAssertion:database credential:credential];
        }];
    }
    else {
        [self continueExitWithPasskeyAssertion:database credential:credential];
    }
}

- (void)continueExitWithPasskeyAssertion:(MacDatabasePreferences*)database
                              credential:(ASPasskeyAssertionCredential*)credential API_AVAILABLE(macos(14.0)) {
    [self markLastUnlockedAtTime:database];
    
    [self notifyMainAppAutoFillExited];
    
    [self.extensionContext completeAssertionRequestWithSelectedPasskeyCredential:credential
                                                               completionHandler:^(BOOL expired) {
        slog(@"🟢 Finished assertion request with expired = %hhd", expired);
    }];
}

- (void)notifyMainAppAutoFillExited {
    

    [DatabasesManager.sharedInstance forceSerialize];
    
    [AutoFillWormholeHelper.sharedInstance postWormholeMessage:kAutoFillWormholeAutoFillExitedNotifyMessageId
                                                    responseId:kAutoFillWormholeAutoFillExitedNotifyResponseId
                                                       message:@{}
                                                    completion:^(BOOL success, NSDictionary<NSString *,id> * _Nullable response) {
        slog(@"🟢 notifyMainAppAutoFillExited done - %hhd", success);
    }];
}

@end
