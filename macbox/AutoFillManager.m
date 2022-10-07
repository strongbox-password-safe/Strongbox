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
#import "SprCompilation.h"
#import "NSString+Extensions.h"
#import "CommonDatabasePreferences.h"
#import "Utils.h"
#import "ConcurrentMutableDictionary.h"
#import "AutoFillCommon.h"



@implementation AutoFillManager 

+ (instancetype)sharedInstance {
    static AutoFillManager *sharedInstance = nil;
    static dispatch_once_t onceToken;
    
    dispatch_once(&onceToken, ^{
        sharedInstance = [[AutoFillManager alloc] init];
    });
    
    return sharedInstance;
}



- (void)updateAutoFillQuickTypeDatabase:(Model*)database
                            databaseUuid:(NSString *)databaseUuid
                            displayFormat:(QuickTypeAutoFillDisplayFormat)displayFormat
                            alternativeUrls:(BOOL)alternativeUrls
                            customFields:(BOOL)customFields
                            notes:(BOOL)notes
                            concealedCustomFieldsAsCreds:(BOOL)concealedCustomFieldsAsCreds
                            unConcealedCustomFieldsAsCreds:(BOOL)unConcealedCustomFieldsAsCreds
                            nickName:(NSString *)nickName API_AVAILABLE(ios(12.0), macos(11.0)) {
    if (! self.isPossible || database == nil) {
        return;
    }

#if TARGET_OS_IPHONE
    if (@available(iOS 12.0, *)) {
#else
    if (@available(macOS 11.0, *)) {
#endif
        [self _updateAutoFillQuickTypeDatabase:database
                                  databaseUuid:databaseUuid
                                 displayFormat:displayFormat
                               alternativeUrls:alternativeUrls
                                  customFields:customFields
                                         notes:notes
                  concealedCustomFieldsAsCreds:concealedCustomFieldsAsCreds
                unConcealedCustomFieldsAsCreds:unConcealedCustomFieldsAsCreds
                                      nickName:nickName];
    }
}

- (void)_updateAutoFillQuickTypeDatabase:(Model*)database
                            databaseUuid:(NSString*)databaseUuid
                           displayFormat:(QuickTypeAutoFillDisplayFormat)displayFormat
                         alternativeUrls:(BOOL)alternativeUrls
                            customFields:(BOOL)customFields
                                   notes:(BOOL)notes
            concealedCustomFieldsAsCreds:(BOOL)concealedCustomFieldsAsCreds
          unConcealedCustomFieldsAsCreds:(BOOL)unConcealedCustomFieldsAsCreds
                            nickName:(NSString *)nickName API_AVAILABLE(ios(12.0), macosx(11.0)) {
    [ASCredentialIdentityStore.sharedStore getCredentialIdentityStoreStateWithCompletion:^(ASCredentialIdentityStoreState * _Nonnull state) {
        if(state.enabled) {
            [self onGotAutoFillStoreOK:database
                          databaseUuid:databaseUuid
                         displayFormat:displayFormat
                       alternativeUrls:alternativeUrls
                          customFields:customFields
                                 notes:notes
          concealedCustomFieldsAsCreds:concealedCustomFieldsAsCreds
        unConcealedCustomFieldsAsCreds:unConcealedCustomFieldsAsCreds nickName:nickName];
        }
        else {
            NSLog(@"AutoFill Credential Store Disabled...");
        }
    }];
}

- (NSArray<Node*>*)sortedNodesWithFavouritesFirst:(Model*)database {
    NSArray<Node*>* allEntries = database.database.allSearchableNoneExpiredEntries;
    
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

- (void)onGotAutoFillStoreOK:(Model*)database
                databaseUuid:(NSString*)databaseUuid
               displayFormat:(QuickTypeAutoFillDisplayFormat)displayFormat
             alternativeUrls:(BOOL)alternativeUrls
                customFields:(BOOL)customFields
                       notes:(BOOL)notes
concealedCustomFieldsAsCreds:(BOOL)concealedCustomFieldsAsCreds
unConcealedCustomFieldsAsCreds:(BOOL)unConcealedCustomFieldsAsCreds
                    nickName:(NSString *)nickName API_AVAILABLE(ios(12.0), macosx(11.0)) {
    NSLog(@"Updating Quick Type AutoFill Database...");
    
    NSMutableArray<ASPasswordCredentialIdentity*> *identities = [NSMutableArray array];
    @try {
        NSArray<Node*>* sortedNodes = [self sortedNodesWithFavouritesFirst:database];
        
        for ( Node* node in sortedNodes ) {
            NSArray<ASPasswordCredentialIdentity*>* nodeIdenitities = [self getPasswordCredentialIdentities:node
                                                                                                   database:database
                                                                                               databaseUuid:databaseUuid
                                                                                              displayFormat:displayFormat
                                                                                            alternativeUrls:alternativeUrls
                                                                                               customFields:customFields
                                                                                                      notes:notes
                                                                               concealedCustomFieldsAsCreds:concealedCustomFieldsAsCreds
                                                                             unConcealedCustomFieldsAsCreds:unConcealedCustomFieldsAsCreds nickName:nickName];
            
            [identities addObjectsFromArray:nodeIdenitities];
        }
    }
    @finally { }
                 
    
    NSUInteger databasesUsingQuickType = [self getDatabasesUsingQuickTypeCount];

    if(databasesUsingQuickType < 2) { 
        [ASCredentialIdentityStore.sharedStore replaceCredentialIdentitiesWithIdentities:identities
                                                                              completion:^(BOOL success, NSError * _Nullable error) {
            NSLog(@"Replaced All Credential Identities... [%d] - [%@]", success, error);
        }];
    }
    else {
        [ASCredentialIdentityStore.sharedStore saveCredentialIdentities:identities
                                                             completion:^(BOOL success, NSError * _Nullable error) {
            NSLog(@"Saved Credential Identities (%lu items)... [%d] - [%@]", (unsigned long) identities.count, success, error);
        }];
    }
}
                                
- (NSArray<ASPasswordCredentialIdentity*>*)getPasswordCredentialIdentities:(Node*)node
                                                                database:(Model*)database
                                                             databaseUuid:(NSString*)databaseUuid
                                                            displayFormat:(QuickTypeAutoFillDisplayFormat)displayFormat
                                                          alternativeUrls:(BOOL)alternativeUrls
                                                             customFields:(BOOL)customFields
                                                                    notes:(BOOL)notes
                                            concealedCustomFieldsAsCreds:(BOOL)concealedCustomFieldsAsCreds
                                          unConcealedCustomFieldsAsCreds:(BOOL)unConcealedCustomFieldsAsCreds
                                nickName:(NSString *)nickName API_AVAILABLE(ios(12.0), macos(11.0)) {
    NSSet<NSString*>* uniqueUrls = [AutoFillCommon getUniqueUrlsForNode:database.database
                                                                   node:node
                                                        alternativeUrls:alternativeUrls
                                                           customFields:customFields
                                                                  notes:notes];
    
    NSMutableArray<ASPasswordCredentialIdentity*> *passwordIdentities = [NSMutableArray array];

    for ( NSString* url in uniqueUrls ) {
        ASPasswordCredentialIdentity* iden = [self getIdentity:node
                                                           url:url
                                                      database:database
                                                  databaseUuid:databaseUuid
                                                 displayFormat:displayFormat
                                                      fieldKey:nil
                                                    fieldValue:nil
                                                      nickName:nickName];
        
        [passwordIdentities addObject:iden];
    }

    [passwordIdentities sortUsingComparator:^NSComparisonResult(id  _Nonnull obj1, id  _Nonnull obj2) {
        ASPasswordCredentialIdentity* i1 = obj1;
        ASPasswordCredentialIdentity* i2 = obj2;

        return finderStringCompare(i1.user, i2.user);
    }];

    

    NSMutableArray<ASPasswordCredentialIdentity*> *customFieldIdentities = [NSMutableArray array];

    for ( NSString* url in uniqueUrls ) {
        for ( NSString* key in node.fields.customFields.allKeys ) {
            if ( ![NodeFields isAlternativeURLCustomFieldKey:key] && ![NodeFields isTotpCustomFieldKey:key] ) {
                StringValue* sv = node.fields.customFields[key];
                
                if ( concealedCustomFieldsAsCreds && sv.protected ) {
                    ASPasswordCredentialIdentity* iden = [self getIdentity:node
                                                                       url:url
                                                                  database:database
                                                              databaseUuid:databaseUuid
                                                             displayFormat:displayFormat
                                                                  fieldKey:key
                                                                fieldValue:sv.value
                                                                  nickName:nickName];
                    [customFieldIdentities addObject:iden];

                }
                else if ( unConcealedCustomFieldsAsCreds && !sv.protected ) {
                    ASPasswordCredentialIdentity* iden = [self getIdentity:node
                                                                       url:url
                                                                  database:database
                                                              databaseUuid:databaseUuid
                                                             displayFormat:displayFormat
                                                                  fieldKey:key
                                                                fieldValue:sv.value
                                                                  nickName:nickName];
                    [customFieldIdentities addObject:iden];
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
                                databaseUuid:(NSString*)databaseUuid
                                displayFormat:(QuickTypeAutoFillDisplayFormat)displayFormat
                                    fieldKey:(NSString*)fieldKey
                                  fieldValue:(NSString*)fieldValue
                            nickName:(NSString *)nickName API_AVAILABLE(ios(12.0), macos(11.0)) {
    QuickTypeRecordIdentifier* recordIdentifier = [QuickTypeRecordIdentifier identifierWithDatabaseId:databaseUuid nodeId:node.uuid.UUIDString fieldKey:fieldKey];
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
        quickTypeText = [NSString stringWithFormat:@"⭐️ %@", quickTypeText];
    }
    
    return [[ASPasswordCredentialIdentity alloc] initWithServiceIdentifier:serviceId user:quickTypeText recordIdentifier:[recordIdentifier toJson]];
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

- (BOOL)isPossible {
#if TARGET_OS_IPHONE
    if (@available(iOS 12.0, *)) {
#else
    if (@available(macOS 11.0, *)) {
#endif
        return YES;
    }
    else {
        return NO;
    }
}

- (BOOL)isOnForStrongbox {
    __block BOOL ret = NO;
    
#if TARGET_OS_IPHONE
    if (@available(iOS 12.0, *)) {
#else
    if (@available(macOS 11.0, *)) {
#endif
        dispatch_group_t g = dispatch_group_create();
        dispatch_group_enter(g);

        [ASCredentialIdentityStore.sharedStore getCredentialIdentityStoreStateWithCompletion:^(ASCredentialIdentityStoreState * _Nonnull state) {
            ret = state.enabled;

            dispatch_group_leave(g);
        }];

        dispatch_group_wait(g, DISPATCH_TIME_FOREVER);
    }

    return ret;
}

- (void)clearAutoFillQuickTypeDatabase API_AVAILABLE(ios(12.0), macos(11.0)) {
#if TARGET_OS_IPHONE
    if (@available(iOS 12.0, *)) {
#else
    if (@available(macOS 11.0, *)) {
#endif
        NSLog(@"Clearing Quick Type AutoFill Database...");
        
        [ASCredentialIdentityStore.sharedStore getCredentialIdentityStoreStateWithCompletion:^(ASCredentialIdentityStoreState * _Nonnull state) {
            if(state.enabled) {
                [ASCredentialIdentityStore.sharedStore removeAllCredentialIdentitiesWithCompletion:nil];
                NSLog(@"Cleared Quick Type AutoFill Database...");
            }
            else {
                NSLog(@"AutoFill QuickType store not enabled. Not Clearing Quick Type AutoFill Database...");
            }
        }];
    }
}

    
@end
