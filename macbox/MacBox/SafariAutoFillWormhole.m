//
//  SafariAutoFillWormhole.m
//  MacBox
//
//  Created by Strongbox on 07/11/2022.
//  Copyright © 2022 Mark McGuill. All rights reserved.
//

#import "SafariAutoFillWormhole.h"
#import "MMWormhole.h"
#import "Settings.h"
#import "AutoFillWormhole.h"
#import "QuickTypeRecordIdentifier.h"
#import "NSArray+Extensions.h"

#import "DatabasesManager.h"

#ifndef IS_APP_EXTENSION
#import "Strongbox-Swift.h"
#else
#import "Strongbox_Auto_Fill-Swift.h"
#endif


@interface SafariAutoFillWormhole ()

@property MMWormhole* wormhole;

@end

@implementation SafariAutoFillWormhole

+ (instancetype)sharedInstance {
    static SafariAutoFillWormhole *sharedInstance = nil;
    static dispatch_once_t onceToken;
    
    dispatch_once(&onceToken, ^{
        sharedInstance = [[SafariAutoFillWormhole alloc] init];
    });
    
    return sharedInstance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        self.wormhole = [[MMWormhole alloc] initWithApplicationGroupIdentifier:Settings.sharedInstance.appGroupName
                                                             optionalDirectory:kAutoFillWormholeName];
        



    }
    
    return self;
}

- (void)cleanupWormhole {
    slog(@"✅ cleanupWormhole");
    
    if ( self.wormhole ) {
        slog(@"Cleaning up wormhole...");
        [self.wormhole clearAllMessageContents];
        self.wormhole = nil; 
    }
}



- (void)listenToAutoFillWormhole {


    __weak SafariAutoFillWormhole* weakSelf = self;
    [self.wormhole listenForMessageWithIdentifier:kAutoFillWormholeQuickTypeRequestId
                                         listener:^(id messageObject) {
        NSDictionary *dict = (NSDictionary*)messageObject;
        NSString* json = dict ? dict[@"id"] : nil;
        [weakSelf onQuickTypeAutoFillWormholeRequest:json];
    }];
        
    
    
    [self.wormhole listenForMessageWithIdentifier:kAutoFillWormholeConvUnlockRequestId
                                         listener:^(id messageObject) {
        NSDictionary *dict = (NSDictionary*)messageObject;
        NSString* databaseId = dict[@"database-id"];
        [weakSelf onAutoFillWormholeMasterCredentialsRequest:databaseId];
    }];
    
    
    
    [self.wormhole listenForMessageWithIdentifier:kAutoFillWormholeSyncRequestId
                                         listener:^(id messageObject) {
        NSDictionary *dict = (NSDictionary*)messageObject;
        NSString* databaseId = dict[@"database-id"];
        [weakSelf onAutoFillReloadAndSyncDatabase:databaseId];
    }];
    
    
    
    [self.wormhole listenForMessageWithIdentifier:kAutoFillWormholePingRequestId
                                         listener:^(id messageObject) {    
        [weakSelf onAutoFillPingWormholeRequest];
    }];

    
    
    [self.wormhole listenForMessageWithIdentifier:kAutoFillWormholeAutoFillExitedNotifyMessageId
                                         listener:^(id messageObject) {
        [weakSelf onAutoFillExitedNotify];
    }];
    
    
    
    if (@available(macOS 14.0, *)) {
        [self.wormhole listenForMessageWithIdentifier:kAutoFillWormholePasskeyAssertionRequestId
                                             listener:^(id messageObject) {
            
            [weakSelf onAutoFillPasskeyAssertionRequest:messageObject];
            
        }];
    }
}



- (void)onAutoFillPingWormholeRequest {
    slog(@"✅ onAutoFillPingWormholeRequest");
    
    NSArray<Model*>* unlocked = [DatabasesCollection.shared getUnlockedDatabases];
    
    NSArray<NSString*>* ret = [[unlocked filter:^BOOL(Model * _Nonnull obj) {
        return obj.metadata.autoFillEnabled;
    }] map:^id _Nonnull(Model * _Nonnull obj, NSUInteger idx) {
        return obj.metadata.uuid;
    }];
    
    slog(@"Responding to onAutoFillPingWormholeRequest  => %@", ret);
    
    [self.wormhole passMessageObject:@{ @"success" : @(YES),
                                        @"unlockedDatabases" : ret }
                          identifier:kAutoFillWormholePingResponseId];
}

- (void)onAutoFillExitedNotify {
    slog(@"✅ onAutoFillExitedNotify");
    
    [DatabasesManager.sharedInstance forceReload];
    
    [self.wormhole passMessageObject:@{ @"success" : @(YES) } identifier:kAutoFillWormholeAutoFillExitedNotifyResponseId];
}

- (void)onAutoFillPasskeyAssertionRequest:(id)messageObject API_AVAILABLE(macos(14.0)) {
    slog(@"✅ onAutoFillPasskeyAssertionRequest");
    
    NSDictionary *dict = (NSDictionary*)messageObject;
    

    
    NSString* json = dict ? dict[@"id"] : nil;
    NSData* clientDataHash = dict ? dict[@"clientDataHash"] : nil;
    

    
    if ( !json || !clientDataHash ) {
        slog(@"🔴 No clientDataHash or QuickTypeIdentifier");
        [self.wormhole passMessageObject:@{ @"success" : @(NO) } identifier:kAutoFillWormholePasskeyAssertionResponseId];
        return;
    }
    
    QuickTypeRecordIdentifier* identifier = [QuickTypeRecordIdentifier fromJson:json];
    if ( !identifier ) {
        slog(@"🔴 Could not decode json for onQuickTypeAutoFillWormholeRequest");
        [self.wormhole passMessageObject:@{ @"success" : @(NO) } identifier:kAutoFillWormholePasskeyAssertionResponseId];
        return;
    }
    
    
    
    Model* model = [DatabasesCollection.shared getUnlockedWithUuid:identifier.databaseId];
    
    if ( !model || !model.metadata.autoFillEnabled ) {
        slog(@"🔴 database is not AutoFillEnabled- %@ - or not unlocked - cannot perform passkey assetion", identifier);
        [self.wormhole passMessageObject:@{ @"success" : @(NO) } identifier:kAutoFillWormholePasskeyAssertionResponseId];
        return;
    }
    
    
    
    NSUUID* uuid = [[NSUUID alloc] initWithUUIDString:identifier.nodeId];
    Node* node = [model getItemById:uuid];
    
    if ( !node || node.isGroup || !node.passkey ) {
        slog(@"[%@] - AutoFill could not find matching node with passkey - returning", model.metadata.nickName);
        [self.wormhole passMessageObject:@{ @"success" : @(NO) } identifier:kAutoFillWormholePasskeyAssertionResponseId];
        return;
    }
    
    
    
    Passkey* passkey = node.passkey;
    
    NSData* authenticatorData = [passkey getAuthenticatorDataWithIncludeAttestedCredentialData:NO];
    if ( !authenticatorData ) {
        slog(@"🔴 Error getting authenticator data");
        [self.wormhole passMessageObject:@{ @"success" : @(NO) } identifier:kAutoFillWormholePasskeyAssertionResponseId];
        return;
    }

    NSError* error;
    NSData* signatureDer = [SwiftUIAutoFillHelper.shared getAutoFillAssertionSignatureDerWithClientDataHash:clientDataHash
                                                                                          authenticatorData:authenticatorData
                                                                                                    passkey:passkey
                                                                                                      error:&error];
    
    if ( !signatureDer ) {
        slog(@"🔴 Error getting signature [%@]", error);
        [self.wormhole passMessageObject:@{ @"success" : @(NO) } identifier:kAutoFillWormholePasskeyAssertionResponseId];
        return;
    }
    
    
    
    NSString* totp = node.fields.otpToken ? node.fields.otpToken.password : @"";

    if ( totp.length && model.metadata.autoFillCopyTotp ) {
        slog(@"🟢 Copy TOTP to clipboard for AutoFill after wormhole request...");
        [ClipboardManager.sharedInstance copyConcealedString:totp];
    }

    [self.wormhole passMessageObject:@{
        @"success" : @(YES),
        @"userHandle": passkey.userHandleData,
        @"relyingParty": passkey.relyingPartyId,
        @"credentialID": passkey.credentialIdData,
        @"signature": signatureDer,
        @"authenticatorData": authenticatorData
    } identifier:kAutoFillWormholePasskeyAssertionResponseId];
}

- (void)onAutoFillReloadAndSyncDatabase:(NSString*)databaseId {
    slog(@"✅ onAutoFillReloadAndSyncDatabase - %@", databaseId);

    [DatabasesManager.sharedInstance forceReload]; 

    MacDatabasePreferences* database = [MacDatabasePreferences getById:databaseId];
    if ( !database.autoFillEnabled ) {
        slog(@"🔴 database is not AutoFillEnabled- %@-%@", database.nickName, databaseId);
        [self.wormhole passMessageObject:@{ @"success" : @(NO) } identifier:kAutoFillWormholeSyncResponseId];
        return;
    }
    
    [DatabasesCollection.shared reloadFromWorkingCopy:databaseId 
                               dispatchSyncAfterwards:YES
                                           completion:nil];

    [self.wormhole passMessageObject:@{ @"success" : @(YES) }
                          identifier:kAutoFillWormholeSyncResponseId];
}

- (void)onAutoFillWormholeMasterCredentialsRequest:(NSString*)databaseId {
    slog(@"✅ onAutoFillWormholeMasterCredentialsRequest: [%@]", databaseId );
    
    Model* model = [DatabasesCollection.shared getUnlockedWithUuid:databaseId];
    
    if ( !model || !model.metadata.autoFillEnabled ) {

        [self.wormhole passMessageObject:@{ @"success" : @(NO) } identifier:kAutoFillWormholeConvUnlockResponseId];
        return;
    }
    
    slog(@"Responding to onAutoFillWormholeMasterCredentialsRequest for Database - %@ ", databaseId);
    
    NSString* secretStoreId = NSUUID.UUID.UUIDString;
    NSDate* expiry = [NSDate.date dateByAddingTimeInterval:5]; 
    
    [SecretStore.sharedInstance setSecureObject:model.database.ckfs.password
                                  forIdentifier:secretStoreId
                                      expiresAt:expiry];
    
    [self.wormhole passMessageObject:@{ @"success" : @(YES), @"secret-store-id" : secretStoreId }
                          identifier:kAutoFillWormholeConvUnlockResponseId];
}

- (void)onQuickTypeAutoFillWormholeRequest:(NSString*)json {
    slog(@"✅ onQuickTypeAutoFillWormholeRequest");
    
    QuickTypeRecordIdentifier* identifier = [QuickTypeRecordIdentifier fromJson:json];
    
    if ( !identifier ) {
        slog(@"🔴 Could not decode json for onQuickTypeAutoFillWormholeRequest");
        [self.wormhole passMessageObject:@{ @"success" : @(NO) }
                              identifier:kAutoFillWormholeQuickTypeResponseId];

        return;
    }

    Model* model = [DatabasesCollection.shared getUnlockedWithUuid:identifier.databaseId];
    
    if (!model || !model.metadata.autoFillEnabled || !model.metadata.quickTypeEnabled ) {
        slog(@"No such database unlocked, or enabled for quick type");
        [self.wormhole passMessageObject:@{ @"success" : @(NO) }
                              identifier:kAutoFillWormholeQuickTypeResponseId];

        return;
    }
    
    
    
    NSUUID* uuid = [[NSUUID alloc] initWithUUIDString:identifier.nodeId];
    Node* node = [model getItemById:uuid];
            
    if ( !node || node.isGroup  ) {
        slog(@"[%@] - AutoFill could not find matching node - returning", model.metadata.nickName);
        [self.wormhole passMessageObject:@{ @"success" : @(NO) }
                              identifier:kAutoFillWormholeQuickTypeResponseId];

        return;
    }
    
    NSString* secretStoreId = NSUUID.UUID.UUIDString;
    NSString* password = @"";
    
    if ( identifier.fieldKey ) {
        StringValue* sv = node.fields.customFields[identifier.fieldKey];
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
    
    password = password ? password : @"";

    NSString* totp = node.fields.otpToken ? node.fields.otpToken.password : @"";
    
    
    
    
    if ( totp.length && model.metadata.autoFillCopyTotp ) {
        slog(@"🟢 Copy TOTP to clipboard for AutoFill after wormhole request...");
        [ClipboardManager.sharedInstance copyConcealedString:totp];
    }
    
    
    
    slog(@"[%@] - AutoFill found matching node - returning", model.metadata.nickName);
    
    NSDictionary* securePayload = @{
        @"user" : user,
        @"password" : password,

    };
    
    NSDate* expiry = [NSDate.date dateByAddingTimeInterval:5]; 
    [SecretStore.sharedInstance setSecureObject:securePayload forIdentifier:secretStoreId expiresAt:expiry];
    
    [self.wormhole passMessageObject:@{ @"success" : @(node != nil),
                                        @"secret-store-id" : secretStoreId }
                          identifier:kAutoFillWormholeQuickTypeResponseId];
}

@end
