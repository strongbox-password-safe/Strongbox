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
#import "Strongbox-Swift.h"
#import "QuickTypeRecordIdentifier.h"

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

- (void)listenToAutoFillWormhole {
    NSLog(@"✅ listenToAutoFillWormhole");

    __weak SafariAutoFillWormhole* weakSelf = self;
    [self.wormhole listenForMessageWithIdentifier:kAutoFillWormholeQuickTypeRequestId
                                         listener:^(id messageObject) {
        NSDictionary *dict = (NSDictionary*)messageObject;
        NSString* userSession = dict[@"user-session-id"];
        
        if ([userSession isEqualToString:NSUserName()]) { 
            NSString* json = dict ? dict[@"id"] : nil;
            [weakSelf onQuickTypeAutoFillWormholeRequest:json];
        }
    }];
    
    
    
    [self.wormhole listenForMessageWithIdentifier:kAutoFillWormholeDatabaseStatusRequestId
                                         listener:^(id messageObject) {
        NSDictionary *dict = (NSDictionary*)messageObject;
        NSString* userSession = dict[@"user-session-id"];
        
        if ( [userSession isEqualToString:NSUserName()] ) { 
            NSString* databaseId = dict[@"database-id"];
            [weakSelf onAutoFillDatabaseUnlockedStatusWormholeRequest:databaseId];
        }
    }];
    
    
    
    [self.wormhole listenForMessageWithIdentifier:kAutoFillWormholeConvUnlockRequestId
                                         listener:^(id messageObject) {
        NSDictionary *dict = (NSDictionary*)messageObject;
        NSString* userSession = dict[@"user-session-id"];
        
        if ( [userSession isEqualToString:NSUserName()] ) { 
            NSString* databaseId = dict[@"database-id"];
            [weakSelf onAutoFillWormholeMasterCredentialsRequest:databaseId];
        }
    }];
}

- (void)cleanupWormhole {
    NSLog(@"✅ cleanupWormhole");
    
    if ( self.wormhole ) {
        NSLog(@"Cleaning up wormhole...");
        [self.wormhole stopListeningForMessageWithIdentifier:kAutoFillWormholeQuickTypeRequestId];
        [self.wormhole stopListeningForMessageWithIdentifier:kAutoFillWormholeDatabaseStatusRequestId];
        [self.wormhole stopListeningForMessageWithIdentifier:kAutoFillWormholeConvUnlockRequestId];
        
        [self.wormhole clearAllMessageContents];
        self.wormhole = nil;
    }
}

- (void)onAutoFillWormholeMasterCredentialsRequest:(NSString*)databaseId {
    NSLog(@"✅ onAutoFillWormholeMasterCredentialsRequest: [%@]", databaseId );
    
    Model* model = [DatabasesCollection.shared getUnlockedWithUuid:databaseId];
    
    if ( !model || !model.metadata.quickWormholeFillEnabled ) {
        NSLog(@"🔴 Model is locked or not enabled for wormhole fill");
        return;
    }
    
    NSLog(@"Responding to Conv Unlock Req for Database - %@ ", databaseId);
    
    NSString* responseId = [NSString stringWithFormat:@"%@-%@", kAutoFillWormholeConvUnlockResponseId, databaseId];
    NSString* secretStoreId = NSUUID.UUID.UUIDString;
    NSDate* expiry = [NSDate.date dateByAddingTimeInterval:5]; 
    [SecretStore.sharedInstance setSecureObject:model.database.ckfs.password
                                  forIdentifier:secretStoreId
                                      expiresAt:expiry];
    
    [self.wormhole passMessageObject:@{  @"user-session-id" : NSUserName(),
                                         @"secret-store-id" : secretStoreId }
                          identifier:responseId];
}

- (void)onAutoFillDatabaseUnlockedStatusWormholeRequest:(NSString*)databaseId {
    NSLog(@"✅ onAutoFillDatabaseUnlockedStatusWormholeRequest - %@", databaseId);
    
    Model* model = [DatabasesCollection.shared getUnlockedWithUuid:databaseId];
    
    if ( !model || !model.metadata.quickWormholeFillEnabled ) {
        NSLog(@"🔴 Model is locked or not enabled for wormhole fill - %@-%@", model.metadata.nickName, databaseId);
        return;
    }

    NSLog(@"Responding to Status Request with Unlock for Database - [%@]-%@-%@", self, model.metadata.nickName, databaseId);
    
    NSString* responseId = [NSString stringWithFormat:@"%@-%@", kAutoFillWormholeDatabaseStatusResponseId, databaseId];
    
    [self.wormhole passMessageObject:@{  @"user-session-id" : NSUserName(), @"unlocked" : databaseId } identifier:responseId];
}

- (void)onQuickTypeAutoFillWormholeRequest:(NSString*)json {
    NSLog(@"✅ onQuickTypeAutoFillWormholeRequest");
    
    QuickTypeRecordIdentifier* identifier = [QuickTypeRecordIdentifier fromJson:json];
    
    if ( !identifier ) {
        NSLog(@"🔴 Could not decode json for onQuickTypeAutoFillWormholeRequest");
        return;
    }

    Model* model = [DatabasesCollection.shared getUnlockedWithUuid:identifier.databaseId];
    
    if (!model || !model.metadata.quickWormholeFillEnabled || !model.metadata.quickTypeEnabled ) {
        NSLog(@"🔴 No such database unlocked, or enabled for quick type");
        return;
    }
    
    
    
    NSUUID* uuid = [[NSUUID alloc] initWithUUIDString:identifier.nodeId];
    Node* node = [model getItemById:uuid];
            
    if ( !node || node.isGroup  ) {
        NSLog(@"[%@] - AutoFill could not find matching node - returning", model.metadata.nickName);
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
    NSString* totp = node.fields.otpToken ? node.fields.otpToken.password : @"";
    
    password = password ? password : @"";
    
    NSLog(@"[%@] - AutoFill found matching node - returning", model.metadata.nickName);
    
    NSDictionary* securePayload = @{
        @"user" : user,
        @"password" : password,
        @"totp" : totp,
    };
    
    NSDate* expiry = [NSDate.date dateByAddingTimeInterval:5]; 
    [SecretStore.sharedInstance setSecureObject:securePayload forIdentifier:secretStoreId expiresAt:expiry];
    
    [self.wormhole passMessageObject:@{ @"user-session-id" : NSUserName(),
                                        @"success" : @(node != nil),
                                        @"secret-store-id" : secretStoreId }
                          identifier:kAutoFillWormholeQuickTypeResponseId];
}

@end
