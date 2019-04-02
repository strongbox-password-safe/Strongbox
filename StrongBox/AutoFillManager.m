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
            if(state.enabled) { // We cannot really support incremental updates - because we do not own/control update mechanisms...
                NSMutableArray<ASPasswordCredentialIdentity*> *identities = [NSMutableArray array];
                
                for (Node* node in database.activeRecords) { 
                    [identities addObjectsFromArray:[self getPasswordCredentialIdentity:node databaseUuid:databaseUuid]];
                }
                
                NSInteger databasesUsingQuickType = [SafesList.sharedInstance.snapshot filter:^BOOL(SafeMetaData * _Nonnull obj) {
                    return obj.useQuickTypeAutoFill;
                }].count;
                
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
            }
            else {
                NSLog(@"AutoFill Credential Store Disabled...");
            }
        }];
    }
}

- (NSArray<ASPasswordCredentialIdentity*>*)getPasswordCredentialIdentity:(Node*)node databaseUuid:(NSString*)databaseUuid  API_AVAILABLE(ios(12.0)){
    if(!node.fields.username.length) {
        return @[];
    }
    
    NSMutableArray<NSString*> *urls = [NSMutableArray array];
    if(node.fields.url.length) {
        [urls addObject:node.fields.url];
    }
    
    // Custom Fields?
    
    for(StringValue* strValue in node.fields.customFields) {
        NSArray<NSString*> *foo = [self findUrlsInString:strValue.value];
        [urls addObjectsFromArray:foo];
    }
    
    // Notes?
    
    if(node.fields.notes.length) {
        NSArray<NSString*> *foo = [self findUrlsInString:node.fields.notes];
        [urls addObjectsFromArray:foo];
    }
    
    NSMutableArray<ASPasswordCredentialIdentity*> *identities = [NSMutableArray array];
    
    for (NSString* url in urls) {
        // NSLog(@"Adding [%@ [%@]] to Quick Type DB", url, node.fields.username);
        
        QuickTypeRecordIdentifier* recordIdentifier = [QuickTypeRecordIdentifier identifierWithDatabaseId:databaseUuid nodeId:node.uuid.UUIDString];
        
        ASCredentialServiceIdentifier* serviceId = [[ASCredentialServiceIdentifier alloc] initWithIdentifier:url type:ASCredentialServiceIdentifierTypeURL];
        ASPasswordCredentialIdentity* iden = [[ASPasswordCredentialIdentity alloc] initWithServiceIdentifier:serviceId user:node.fields.username recordIdentifier:[recordIdentifier toJson]];
        [identities addObject:iden];
    }
    
    return identities;
}

- (NSArray<NSString*>*)findUrlsInString:(NSString*)target {
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
