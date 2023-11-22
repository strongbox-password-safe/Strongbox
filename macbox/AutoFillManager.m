//
//  AutoFillManager.m
//  Strongbox
//
//  Created by Mark on 01/04/2019.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import "AutoFillManager.h"
#import <AuthenticationServices/AuthenticationServices.h>
#import "QuickTypeRecordIdentifier.h"
#import "NSArray+Extensions.h"
#import "NSDate+Extensions.h"
#import "SprCompilation.h"
#import "NSString+Extensions.h"
#import "CommonDatabasePreferences.h"
#import "Utils.h"
#import "ConcurrentMutableDictionary.h"
#import "AutoFillCommon.h"
#import "CrossPlatform.h"
#import "Node+Passkey.h"



#ifndef IS_APP_EXTENSION
#import "Strongbox-Swift.h"
#else
#import "Strongbox_Auto_Fill-Swift.h"
#endif














@implementation AutoFillManager 

+ (instancetype)sharedInstance {
    static AutoFillManager *sharedInstance = nil;
    static dispatch_once_t onceToken;
    
    dispatch_once(&onceToken, ^{
        sharedInstance = [[AutoFillManager alloc] init];
    });
    
    return sharedInstance;
}

- (void)updateAutoFillQuickTypeDatabase:(Model *)database {
    [self updateAutoFillQuickTypeDatabase:database clearFirst:NO];
}

- (void)updateAutoFillQuickTypeDatabase:(Model *)database clearFirst:(BOOL)clearFirst {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0L), ^{
        [ASCredentialIdentityStore.sharedStore getCredentialIdentityStoreStateWithCompletion:^(ASCredentialIdentityStoreState * _Nonnull state) {
            if ( state.enabled ) {
                if ( clearFirst ) {
                    [ASCredentialIdentityStore.sharedStore removeAllCredentialIdentitiesWithCompletion:^(BOOL success, NSError * _Nullable error) {
                        if ( error ) {
                            NSLog(@"🔴 Cleared Quick Type AutoFill Database with error = [%@]...", error);
                        }
                        else {
                            NSLog(@"🟢 Cleared Quick Type AutoFill Database");
                        }
                        
                        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0L), ^{
                            [self loadIdentitiesFromDb:database];
                        });
                    }];
                    NSLog(@"Cleared Quick Type AutoFill Database...");
                }
                else {
                    [self loadIdentitiesFromDb:database];
                }
            }
        }];
    });
}

- (void)loadIdentitiesFromDb:(Model*)database {

    
    NSTimeInterval start = NSDate.timeIntervalSinceReferenceDate;
        
    NSMutableArray *identities = [NSMutableArray array];
    
    @try {
        NSArray<Node*>* sortedNodes = [self getFilteredSortedNodes:database];
        
        for ( Node* node in sortedNodes ) {
            if ( database.metadata.quickTypeEnabled ) {
                NSArray<ASPasswordCredentialIdentity*>* nodeIdenitities = [self getPasswordCredentialIdentities:node database:database];
                
                [identities addObjectsFromArray:nodeIdenitities];
            }
            
            if (@available(iOS 17.0, macOS 14.0, *)) {
                if ( node.passkey ) {
                    ASPasskeyCredentialIdentity *pkid = [self getPasskeyAutoFillCredentialIdentity:node databaseUuid:database.metadata.uuid];
                        
                    if ( pkid ) {
                        [identities addObject:pkid];
                    }
                }
            }
        }
    }
    @finally { }
    
    [self setQuickTypeSuggestions:identities];
    
    NSLog(@"🟢 ⏱️ Updated Quick Type AutoFill Database in [%f] seconds", NSDate.timeIntervalSinceReferenceDate - start);
}

- (NSArray<Node*>*)getFilteredSortedNodes:(Model*)database {
    NSArray<Node*>* allSearchable = database.database.allSearchableNoneExpiredEntries;
    
    NSArray<Node*>* allEntries = [allSearchable filter:^BOOL(Node * _Nonnull obj) {
        return ![database isExcludedFromAutoFill:obj.uuid];
    }];
    
    NSArray<Node*>* sortedEntries = [allEntries sortedArrayUsingComparator:^NSComparisonResult(id  _Nonnull obj1, id  _Nonnull obj2) {
        Node* n1 = (Node*)obj1;
        Node* n2 = (Node*)obj2;
        
        BOOL f1 = [database isFavourite:n1.uuid];
        BOOL f2 = [database isFavourite:n2.uuid];
        
        if ( ( !f1 && !f2 ) || ( f1  &&  f2 ) ) {
            NSComparisonResult retTitle = finderStringCompare(n1.title, n2.title);
            
            if ( retTitle == NSOrderedSame ) {
                return finderStringCompare( n1.fields.username, n2.fields.username );
            }
            else {
                return retTitle;
            }
        }
        else {
            return f1 ? NSOrderedAscending : NSOrderedDescending;
        }
    }];
    
    return sortedEntries;
}

- (ASPasskeyCredentialIdentity*)getPasskeyAutoFillCredentialIdentity:(Node*)node databaseUuid:(NSString*)databaseUuid API_AVAILABLE(ios(17.0), macos (14.0)) {
    if ( node.passkey == nil ) {
        return nil;
    }
    
    QuickTypeRecordIdentifier* rid = [QuickTypeRecordIdentifier identifierWithDatabaseId:databaseUuid nodeId:node.uuid.UUIDString fieldKey:nil];
    
    Passkey* pk = node.passkey;
    ASPasskeyCredentialIdentity *pkid = [ASPasskeyCredentialIdentity identityWithRelyingPartyIdentifier:pk.relyingPartyId
                                                                                               userName:pk.username
                                                                                           credentialID:pk.credentialIdData
                                                                                             userHandle:pk.userHandleData
                                                                                       recordIdentifier:[rid toJson]];
    
    return pkid;
}
                                
- (NSArray<ASPasswordCredentialIdentity*>*)getPasswordCredentialIdentities:(Node*)node
                                                                  database:(Model*)database {
    NSSet<NSString*>* uniqueUrls = [AutoFillCommon getUniqueUrlsForNode:database node:node];
    
    NSMutableArray<ASPasswordCredentialIdentity*> *passwordIdentities = [NSMutableArray array];

    if ( node.fields.username.length && node.fields.password.length ) { 
        for ( NSString* url in uniqueUrls ) {
            ASPasswordCredentialIdentity* iden = [self getIdentity:node url:url database:database fieldKey:nil fieldValue:nil];
            
            [passwordIdentities addObject:iden];
        }
    }

    [passwordIdentities sortUsingComparator:^NSComparisonResult(id  _Nonnull obj1, id  _Nonnull obj2) {
        ASPasswordCredentialIdentity* i1 = obj1;
        ASPasswordCredentialIdentity* i2 = obj2;

        return finderStringCompare(i1.user, i2.user);
    }];

    

    NSMutableArray<ASPasswordCredentialIdentity*> *customFieldIdentities = [NSMutableArray array];

    for ( NSString* url in uniqueUrls ) {
        for ( NSString* key in node.fields.customFields.allKeys ) {
            if (![NodeFields isAlternativeURLCustomFieldKey:key] &&
                ![NodeFields isTotpCustomFieldKey:key] &&
                ![NodeFields isPasskeyCustomFieldKey:key] ) {
                StringValue* sv = node.fields.customFields[key];
                
                if ( database.metadata.autoFillConcealedFieldsAsCreds && sv.protected ) {
                    if ( sv.value.length ) {
                        ASPasswordCredentialIdentity* iden = [self getIdentity:node
                                                                           url:url
                                                                      database:database
                                                                      fieldKey:key
                                                                    fieldValue:sv.value];
                        
                        [customFieldIdentities addObject:iden];
                    }

                }
                else if ( database.metadata.autoFillUnConcealedFieldsAsCreds && !sv.protected ) {
                    if ( sv.value.length ) {
                        ASPasswordCredentialIdentity* iden = [self getIdentity:node
                                                                           url:url
                                                                      database:database
                                                                      fieldKey:key
                                                                    fieldValue:sv.value];
                        [customFieldIdentities addObject:iden];
                    }
                }
            }
        }
    }

    [customFieldIdentities sortUsingComparator:^NSComparisonResult(id  _Nonnull obj1, id  _Nonnull obj2) {
        ASPasswordCredentialIdentity* i1 = obj1;
        ASPasswordCredentialIdentity* i2 = obj2;

        return finderStringCompare(i1.user, i2.user);
    }];

    [passwordIdentities addObjectsFromArray:customFieldIdentities];
    
    return passwordIdentities;
}
                                
- (ASPasswordCredentialIdentity*)getIdentity:(Node*)node
                                         url:(NSString*)url
                                    database:(Model*)database
                                    fieldKey:(NSString*)fieldKey
                                  fieldValue:(NSString*)fieldValue {
    QuickTypeRecordIdentifier* recordIdentifier = [QuickTypeRecordIdentifier identifierWithDatabaseId:database.metadata.uuid nodeId:node.uuid.UUIDString fieldKey:fieldKey];
    ASCredentialServiceIdentifier* serviceId = [[ASCredentialServiceIdentifier alloc] initWithIdentifier:url type:ASCredentialServiceIdentifierTypeURL];
    
    NSString* username;
    if ( fieldKey == nil ) {
        username = [database dereference:node.fields.username node:node];
    }
    else {
        username = fieldKey;
    }
    
    NSString* title = [database dereference:node.title node:node];
    title = title.length ? title : NSLocalizedString(@"generic_unknown", @"Unknown");
    
    NSString* quickTypeText = title;
    
    QuickTypeAutoFillDisplayFormat displayFormat = database.metadata.quickTypeDisplayFormat;
    NSString* nickName = database.metadata.nickName;
    
    if ( displayFormat == kQuickTypeFormatTitleThenUsername && username.length) {
        quickTypeText = [NSString stringWithFormat:@"%@ (%@)", title, username];
    }
    else if ( displayFormat == kQuickTypeFormatUsernameOnly && username.length ) {
        quickTypeText = username;
    }
    else if ( displayFormat == kQuickTypeFormatDatabaseThenTitleThenUsername && username.length) {
        quickTypeText = [NSString stringWithFormat:@"[%@] %@ (%@)", nickName, title, username];
    }
    else if ( displayFormat == kQuickTypeFormatDatabaseThenUsername && username.length) {
        quickTypeText = [NSString stringWithFormat:@"[%@] %@", nickName, username];
    }
    else if ( displayFormat == kQuickTypeFormatDatabaseThenTitle) {
        quickTypeText = [NSString stringWithFormat:@"[%@] %@", nickName, title];
    }
    else if ( fieldKey != nil ) {
        quickTypeText = username;
    }
    
    if ( [database isFavourite:node.uuid] ) {
        quickTypeText = [NSString stringWithFormat:@"%@ ⭐️", quickTypeText];
    }
    
    return [[ASPasswordCredentialIdentity alloc] initWithServiceIdentifier:serviceId user:quickTypeText recordIdentifier:[recordIdentifier toJson]];
}
        
- (void)setQuickTypeSuggestions:(NSArray<ASPasswordCredentialIdentity*>*)identities {
    
    NSUInteger databasesUsingQuickType = [self getDatabasesUsingQuickTypeCount];
    
    if(databasesUsingQuickType < 2) { 
        if ( identities.count == 0 ) { 
            [ASCredentialIdentityStore.sharedStore removeAllCredentialIdentitiesWithCompletion:^(BOOL success, NSError * _Nullable error) {
                NSLog(@"✅ removeAllCredentialIdentities because zero passed in... [%d] - [%@]", success, error);
            }];
            return;
        }
        else {
            [ASCredentialIdentityStore.sharedStore replaceCredentialIdentitiesWithIdentities:identities
                                                                                  completion:^(BOOL success, NSError * _Nullable error) {

            }];
        }
    }
    else {
        NSDate* lastFullClear = CrossPlatformDependencies.defaults.applicationPreferences.lastQuickTypeMultiDbRegularClear;
        
        
        
        if ( lastFullClear == nil || [lastFullClear isMoreThanXDaysAgo:14] ) { 
            NSLog(@"✅ Doing a full clear of the QuickType AutoFill database because the last clear was on [%@]", lastFullClear.friendlyDateString);
            
            [ASCredentialIdentityStore.sharedStore removeAllCredentialIdentitiesWithCompletion:nil];
            
            CrossPlatformDependencies.defaults.applicationPreferences.lastQuickTypeMultiDbRegularClear = NSDate.date;
        }
        
        [ASCredentialIdentityStore.sharedStore saveCredentialIdentities:identities
                                                             completion:^(BOOL success, NSError * _Nullable error) {

        }];
    }
}

- (NSUInteger)getDatabasesUsingQuickTypeCount {
#if TARGET_OS_IPHONE
    NSUInteger databasesUsingQuickType = [CommonDatabasePreferences filteredDatabases:^BOOL(DatabasePreferences * _Nonnull obj) {
        return obj.autoFillEnabled && obj.quickTypeEnabled;
    }].count;
    
#else
    NSUInteger databasesUsingQuickType = [CommonDatabasePreferences filteredDatabases:^BOOL(MacDatabasePreferences * _Nonnull database) {
        return database.autoFillEnabled && database.quickTypeEnabled;
    }].count;
#endif
        
    return databasesUsingQuickType;
}

- (BOOL)isOnForStrongbox {
    __block BOOL ret = NO;
    
    dispatch_group_t g = dispatch_group_create();
    dispatch_group_enter(g);
    
    [ASCredentialIdentityStore.sharedStore getCredentialIdentityStoreStateWithCompletion:^(ASCredentialIdentityStoreState * _Nonnull state) {
        ret = state.enabled;
        
        dispatch_group_leave(g);
    }];
    
    dispatch_group_wait(g, DISPATCH_TIME_FOREVER);

    return ret;
}

- (void)clearAutoFillQuickTypeDatabase {
    NSLog(@"Clearing Quick Type AutoFill Database...");

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0L), ^{
        [ASCredentialIdentityStore.sharedStore removeAllCredentialIdentitiesWithCompletion:^(BOOL success, NSError * _Nullable error) {
            if ( error ) {
                NSLog(@"🔴 Cleared Quick Type AutoFill Database with error = [%@]...", error);
            }
            else {
                NSLog(@"🟢 Cleared Quick Type AutoFill Database");
            }
        }];
    });
}

- (void)refreshQuickTypeAfterAutoFillAddition:(Node*)node database:(Model*)database {
    if ( node.passkey ) {
        if (@available(iOS 17.0, macOS 14.0, *)) {
            ASPasskeyCredentialIdentity *pkid = [self getPasskeyAutoFillCredentialIdentity:node databaseUuid:database.metadata.uuid];
            
            [ASCredentialIdentityStore.sharedStore saveCredentialIdentityEntries:@[pkid]
                                                                      completion:^(BOOL success, NSError * _Nullable error) {
                NSLog(@"refreshQuickTypeAfterAutoFillAddition Passkey Done: %hhd - %@", success, error);
            }];
        }
    }
    else {
        ASPasswordCredentialIdentity* aspcid = [self getIdentity:node url:node.fields.url database:database fieldKey:nil fieldValue:nil];
        
        [ASCredentialIdentityStore.sharedStore saveCredentialIdentities:@[aspcid]
                                                             completion:^(BOOL success, NSError * _Nullable error) {
            NSLog(@"refreshQuickTypeAfterAutoFillAddition Done: %hhd - %@", success, error);
        }];
    }
}

- (void)removeItemsFromQuickType:(const NSArray<Node *> *)items database:(Model *)database {
    for ( Node* node in items ) {
        NSLog(@"   Removing [%@]", node.title);
        NSArray<ASPasswordCredentialIdentity*>* identities = [self getPasswordCredentialIdentities:node database:database];
        
        [ASCredentialIdentityStore.sharedStore removeCredentialIdentities:identities
                                                               completion:^(BOOL success, NSError * _Nullable error) {
            NSLog(@"🟢 removeCredentialIdentities done with %hhd - %@", success, error);
        }];
        
        if (@available(iOS 17.0, macOS 14.0, *)) {
            if ( node.passkey ) {
                ASPasskeyCredentialIdentity *pkid = [self getPasskeyAutoFillCredentialIdentity:node databaseUuid:database.metadata.uuid];
                [ASCredentialIdentityStore.sharedStore removeCredentialIdentityEntries:@[pkid]
                                                                            completion:^(BOOL success, NSError * _Nullable error) {
                    NSLog(@"🟢 removeCredentialIdentityEntries done with %hhd - %@", success, error);
                }];
            }
        }
    }
}

@end
