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

#if TARGET_OS_IPHONE
#import "SVProgressHUD.h"
#import "SafesList.h"
#else
#import "DatabasesManager.h"
#endif



static NSString* const kOtpAuthScheme = @"otpauth";
static NSString* const kMailToScheme = @"mailto";

@implementation AutoFillManager

+ (instancetype)sharedInstance {
    static AutoFillManager *sharedInstance = nil;
    static dispatch_once_t onceToken;
    
    dispatch_once(&onceToken, ^{
        sharedInstance = [[AutoFillManager alloc] init];
    });
    
    return sharedInstance;
}

- (void)clearAutoFillQuickTypeDatabase {
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

- (void)updateAutoFillQuickTypeDatabase:(DatabaseModel*)database databaseUuid:(NSString*)databaseUuid displayFormat:(QuickTypeAutoFillDisplayFormat)displayFormat {
    if (! self.isPossible || database == nil) {
        return;
    }

#if TARGET_OS_IPHONE
    NSInteger databasesUsingQuickType = [SafesList.sharedInstance.snapshot filter:^BOOL(SafeMetaData * _Nonnull obj) {
        return obj.autoFillEnabled && obj.quickTypeEnabled;
    }].count;
    
    if (@available(iOS 12.0, *)) {
#else
    NSInteger databasesUsingQuickType = [DatabasesManager.sharedInstance.snapshot filter:^BOOL(DatabaseMetadata * _Nonnull obj) {
        return obj.autoFillEnabled && obj.quickTypeEnabled;
    }].count;
    
    
    if (@available(macOS 11.0, *)) {
#endif
        [ASCredentialIdentityStore.sharedStore getCredentialIdentityStoreStateWithCompletion:^(ASCredentialIdentityStoreState * _Nonnull state) {
            if(state.enabled) {
                NSLog(@"Updating Quick Type AutoFill Database...");
                
                NSMutableArray<ASPasswordCredentialIdentity*> *identities = [NSMutableArray array];
                @try {
                    for ( Node* node in database.allSearchableEntries ) {
                        [identities addObjectsFromArray:[self getPasswordCredentialIdentity:node database:database databaseUuid:databaseUuid displayFormat:displayFormat]];
                    }
                }
                @finally { }
                
                
                
                if(databasesUsingQuickType < 2) { 
                    [ASCredentialIdentityStore.sharedStore replaceCredentialIdentitiesWithIdentities:identities completion:^(BOOL success, NSError * _Nullable error) {
                        NSLog(@"Replaced All Credential Identities... [%d] - [%@]", success, error);
                    }];
                }
                else {
                    [ASCredentialIdentityStore.sharedStore saveCredentialIdentities:identities completion:^(BOOL success, NSError * _Nullable error) {
                        NSLog(@"Saved Credential Identities (%lu items)... [%d] - [%@]", (unsigned long) identities.count, success, error);
                    }];
                }
            }
            else {
                NSLog(@"AutoFill Credential Store Disabled...");
            }
        }];
    }
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
    
- (NSArray<ASPasswordCredentialIdentity*>*)getPasswordCredentialIdentity:(Node*)node
                                                                database:(DatabaseModel*)database
                                                            databaseUuid:(NSString*)databaseUuid
                                                           displayFormat:(QuickTypeAutoFillDisplayFormat)displayFormat
    API_AVAILABLE(ios(12.0), macos(11.0)) {
#if TARGET_OS_IPHONE
    if (@available(iOS 12.0, *)) {
#else
    if (@available(macOS 11.0, *)) {
#endif
        NSMutableSet<NSString*> *uniqueUrls = [NSMutableSet set];

        NSMutableArray<NSString*> *explicitUrls = [NSMutableArray array];
        
        
        
        NSString* urlField = [database dereference:node.fields.url node:node];
        if(urlField.length) {
            [explicitUrls addObject:urlField];
        }
        
        
        
        for ( NSString* altUrl in node.fields.alternativeUrls) {
            if(altUrl.length) {
                NSString* derefed = [database dereference:altUrl node:node];
                [explicitUrls addObject:derefed];
            }
        }
        
        

        for ( NSString* expUrl in explicitUrls ) {
            NSURL* parsed = expUrl.urlExtendedParse;

            if ( parsed ) {
                NSURLComponents* components = [NSURLComponents componentsWithURL:parsed resolvingAgainstBaseURL:NO];
                
                if ( !components.scheme.length ) { 
                    NSString* urlString = [NSString stringWithFormat:@"https:
                    [uniqueUrls addObject:urlString];
                }
                else {
                    [uniqueUrls addObject:expUrl];
                }
            }
            else {
                [uniqueUrls addObject:expUrl];
            }
        }
        
        
        
        for(NSString* key in node.fields.customFields.allKeys) {
            if ( ![NodeFields isAlternativeURLCustomFieldKey:key] ) { 
                StringValue* strValue = node.fields.customFields[key];
                NSArray<NSString*> *foo = [self findUrlsInString:strValue.value];
                [uniqueUrls addObjectsFromArray:foo];
            }
        }
        
        

        NSString* notesField = [database dereference:node.fields.notes node:node];

        if(notesField.length) {
            NSArray<NSString*> *foo = [self findUrlsInString:notesField];
            [uniqueUrls addObjectsFromArray:foo];
        }
        
        NSMutableArray<ASPasswordCredentialIdentity*> *identities = [NSMutableArray array];
    
        for ( NSString* url in uniqueUrls ) {
            QuickTypeRecordIdentifier* recordIdentifier = [QuickTypeRecordIdentifier identifierWithDatabaseId:databaseUuid nodeId:node.uuid.UUIDString];
            
            ASCredentialServiceIdentifier* serviceId = [[ASCredentialServiceIdentifier alloc] initWithIdentifier:url type:ASCredentialServiceIdentifierTypeURL];
            
            NSString* username = [database dereference:node.fields.username node:node];
            NSString* title = [database dereference:node.title node:node];
            title = title.length ? title : NSLocalizedString(@"generic_unknown", @"Unknown");
            
            NSString* quickTypeText;
            
            if ( displayFormat == kQuickTypeFormatTitleThenUsername && username.length) {
                quickTypeText = [NSString stringWithFormat:@"%@ (%@)", title, username];
            }
            else if ( displayFormat == kQuickTypeFormatUsernameOnly && username.length ) {
                quickTypeText = username;
            }
            else {
                quickTypeText = title;
            }

            
            
            ASPasswordCredentialIdentity* iden = [[ASPasswordCredentialIdentity alloc] initWithServiceIdentifier:serviceId user:quickTypeText recordIdentifier:[recordIdentifier toJson]];
            [identities addObject:iden];
        }
        
        return identities;
    }
    else {
        return @[];
    }
}

- (NSArray<NSString*>*)findUrlsInString:(NSString*)target {
    if(!target.length) {
        return @[];
    }
    
    NSError *error;
    NSDataDetector* detector = [NSDataDetector dataDetectorWithTypes:NSTextCheckingTypeLink error:&error];
    
    NSMutableArray<NSString*>* urls = [NSMutableArray array];
    
    if(detector) {
        NSArray *matches = [detector matchesInString:target
                                             options:0
                                               range:NSMakeRange(0, [target length])];
        for (NSTextCheckingResult *match in matches) {
            if ([match resultType] == NSTextCheckingTypeLink) {
                NSURL *url = [match URL];
                if(url && url.scheme && ![url.scheme isEqualToString:kOtpAuthScheme] && ![url.scheme isEqualToString:kMailToScheme]) {
                    [urls addObject:url.absoluteString];
                }
            }
        }
    }
    else {
        NSLog(@"Error finding Urls: %@", error);
    }
    
    return urls;
}

@end
