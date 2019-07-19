//
//  AutoFillManager.m
//  Strongbox
//
//  Created by Mark on 01/04/2019.
//  Copyright © 2019 Mark McGuill. All rights reserved.
//

#import "AutoFillManager.h"
#import <AuthenticationServices/AuthenticationServices.h>
#import "QuickTypeRecordIdentifier.h"
#import "SafesList.h"
#import "NSArray+Extensions.h"
#import "SVProgressHUD.h"
#import "SprCompilation.h"

//////////////////////////////////////////////////////////////////////////////////////////////////////

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
    if (@available(iOS 12.0, *)) {
        NSLog(@"Clearing Quick Type AutoFill Database...");
        
        [ASCredentialIdentityStore.sharedStore getCredentialIdentityStoreStateWithCompletion:^(ASCredentialIdentityStoreState * _Nonnull state) {
            if(state.enabled) {
                [ASCredentialIdentityStore.sharedStore removeAllCredentialIdentitiesWithCompletion:nil];
            }
        }];
    }
}

- (void)updateAutoFillQuickTypeDatabase:(DatabaseModel*)database databaseUuid:(NSString*)databaseUuid {
    if (@available(iOS 12.0, *)) {
        NSLog(@"Updating Quick Type AutoFill Database...");
        
        [ASCredentialIdentityStore.sharedStore getCredentialIdentityStoreStateWithCompletion:^(ASCredentialIdentityStoreState * _Nonnull state) {
            if(state.enabled) {
                // We cannot really support incremental updates - because we do not own/control update mechanisms...
                dispatch_async(dispatch_get_main_queue(), ^{
                    [SVProgressHUD showWithStatus:@"Populating AutoFill..."];
                });
                
                NSMutableArray<ASPasswordCredentialIdentity*> *identities = [NSMutableArray array];
                
                for (Node* node in database.activeRecords) { 
                    [identities addObjectsFromArray:[self getPasswordCredentialIdentity:node database:database databaseUuid:databaseUuid]];
                }
                
                NSInteger databasesUsingQuickType = SafesList.sharedInstance.snapshot.count;
                
                if(databasesUsingQuickType < 2) { // We can safely replace all, otherwise must append... This isn't ideal in the multiple scenario as we end up with stales :(
                    [ASCredentialIdentityStore.sharedStore replaceCredentialIdentitiesWithIdentities:identities completion:^(BOOL success, NSError * _Nullable error) {
                        NSLog(@"Replaced All Credential Identities... [%d] - [%@]", success, error);
                    }];
                }
                else {
                    [ASCredentialIdentityStore.sharedStore saveCredentialIdentities:identities completion:^(BOOL success, NSError * _Nullable error) {
                        NSLog(@"Saved Credential Identities... [%d] - [%@]", success, error);
                    }];
                }
                
                dispatch_async(dispatch_get_main_queue(), ^{
                    [SVProgressHUD dismiss];
                });
            }
            else {
                NSLog(@"AutoFill Credential Store Disabled...");
            }
        }];
    }
}

- (NSArray<ASPasswordCredentialIdentity*>*)getPasswordCredentialIdentity:(Node*)node database:(DatabaseModel*)database databaseUuid:(NSString*)databaseUuid  API_AVAILABLE(ios(12.0)){
    if(!node.fields.username.length) {
        return @[];
    }
    
    NSMutableArray<NSString*> *urls = [NSMutableArray array];
    
    NSString* urlField = [database dereference:node.fields.url node:node];
    if(urlField.length) {
        [urls addObject:urlField];
    }
    
    // Custom Fields?
    
    for(NSString* key in node.fields.customFields.allKeys) {
        StringValue* strValue = node.fields.customFields[key];
        NSArray<NSString*> *foo = [self findUrlsInString:strValue.value];
        [urls addObjectsFromArray:foo];
    }
    
    // Notes?

    NSString* notesField = [database dereference:node.fields.notes node:node];

    if(notesField.length) {
        NSArray<NSString*> *foo = [self findUrlsInString:notesField];
        [urls addObjectsFromArray:foo];
    }
    
    NSMutableArray<ASPasswordCredentialIdentity*> *identities = [NSMutableArray array];
    
    for (NSString* url in urls) {
        QuickTypeRecordIdentifier* recordIdentifier = [QuickTypeRecordIdentifier identifierWithDatabaseId:databaseUuid nodeId:node.uuid.UUIDString];
        
        ASCredentialServiceIdentifier* serviceId = [[ASCredentialServiceIdentifier alloc] initWithIdentifier:url type:ASCredentialServiceIdentifierTypeURL];
        
        NSString* usernameField = [database dereference:node.fields.username node:node];

        // NSLog(@"Adding [%@ [%@]] to Quick Type DB", url, usernameField);
        
        ASPasswordCredentialIdentity* iden = [[ASPasswordCredentialIdentity alloc] initWithServiceIdentifier:serviceId user:usernameField recordIdentifier:[recordIdentifier toJson]];
        [identities addObject:iden];
    }
    
    return identities;
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
