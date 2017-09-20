//
//  SafeViewModel.m
//  StrongBox
//
//  Created by Mark McGuill on 20/06/2014.
//  Copyright (c) 2014 Mark McGuill. All rights reserved.
//

#import "Model.h"
#import "Utils.h"
#import "SVProgressHUD.h"

@interface Model ()

@property (readonly, strong, nonatomic) PasswordDatabase *passwordDatabase;

@end

@implementation Model {
    id <SafeStorageProvider> _storageProvider;
    BOOL _isUsingOfflineCache;
    BOOL _isReadOnly;
}

- (instancetype)initWithSafeDatabase:(PasswordDatabase *)passwordDatabase
                            metaData:(SafeMetaData *)metaData
                     storageProvider:(id <SafeStorageProvider>)provider
                   usingOfflineCache:(BOOL)usingOfflineCache
                          isReadOnly:(BOOL)isReadOnly {
    if (self = [super init]) {
        _passwordDatabase = passwordDatabase;
        _metadata = metaData;
        _storageProvider = provider;
        _isUsingOfflineCache = usingOfflineCache;
        _isReadOnly = isReadOnly;

        return self;
    }
    else {
        return nil;
    }
}

- (Node*)rootGroup {
    return self.passwordDatabase.rootGroup;
}

- (BOOL)isCloudBasedStorage {
    return _storageProvider.cloudBased;
}

- (BOOL)isUsingOfflineCache {
    return _isUsingOfflineCache;
}

- (BOOL)isReadOnly {
    return _isReadOnly;
}

- (void)update:(void (^)(NSError *error))handler {
    if (!_isUsingOfflineCache && !_isReadOnly) {
        [self.passwordDatabase defaultLastUpdateFieldsToNow];
        
        [self encrypt:^(NSData * _Nullable updatedSafeData, NSError * _Nullable error) {
            if (updatedSafeData == nil) {
                handler(error);
                return;
            }

            [_storageProvider update:self.metadata
                                data:updatedSafeData
                          completion:^(NSError *error) {
                              [self updateOfflineCacheWithData:updatedSafeData];
                              handler(error);
                          }];
        }];
    }
    else {
        if(_isReadOnly) {
            handler([Utils createNSError:@"You are in read-only mode. You will need to upgrade Strongbox to write to safes." errorCode:-1]);
        }
        else {
            handler([Utils createNSError:@"You are currently in offline mode. The safe cannot be modified." errorCode:-1]);
        }
    }
}

- (void)updateOfflineCache:(void (^)(void))handler {
    if (self.isCloudBasedStorage && !self.isUsingOfflineCache && _metadata.offlineCacheEnabled) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void)
        {
            NSError *error;
            NSData *updatedSafeData = [self.passwordDatabase getAsData:&error];

            dispatch_async(dispatch_get_main_queue(), ^(void) {
                if (updatedSafeData != nil && _metadata.offlineCacheEnabled) {
                    NSLog(@"Updating offline cache for safe.");
                    [self saveOfflineCacheFile:updatedSafeData safe:_metadata];
                }

                handler();
            });
        });
    }
}

- (void)updateOfflineCacheWithData:(NSData *)data {
    if (self.isCloudBasedStorage && !self.isUsingOfflineCache && _metadata.offlineCacheEnabled) {
        NSLog(@"Updating offline cache for safe.");
        [self saveOfflineCacheFile:data safe:_metadata];
    }
}

- (void)saveOfflineCacheFile:(NSData *)data
                        safe:(SafeMetaData *)safe {
    // Store this safe locally
    // Do we already have a file?
    //      Yes-> Overwrite
    //      No-> Create New & Set location

    if (safe.offlineCacheAvailable) {
        [[LocalDeviceStorageProvider sharedInstance] updateOfflineCachedSafe:safe
                                          data:data
                                viewController:nil
                                    completion:^(NSError *error) {
                                        [self  onStoredOfflineCacheFile:safe
                                        error:error];
                                    }];
    }
    else {
        safe.offlineCacheFileIdentifier = [[NSUUID alloc] init].UUIDString;

        [[LocalDeviceStorageProvider sharedInstance] createOfflineCacheFile:safe.offlineCacheFileIdentifier data:data completion:^(NSError *error) {
            [self  onStoredOfflineCacheFile:safe error:error];
        }];
    }
}

- (void)onStoredOfflineCacheFile:(SafeMetaData *)safe error:(NSError *)error {
    if (error != nil) {
        NSLog(@"Error updating Offline Cache file. %@", error);

        safe.offlineCacheAvailable = NO;
        safe.offlineCacheFileIdentifier = @"";
    }
    else {
        //NSLog(@"Offline cache save with name: %@", safe.offlineCacheFileIdentifier);
        safe.offlineCacheAvailable = YES;
    }

    [[SafesCollection sharedInstance] save];
}

- (void)disableAndClearOfflineCache {
    [[LocalDeviceStorageProvider sharedInstance] deleteOfflineCachedSafe:_metadata
                         completion:^(NSError *error) {
                             _metadata.offlineCacheEnabled = NO;
                             _metadata.offlineCacheAvailable = NO;
                             _metadata.offlineCacheFileIdentifier = @"";

                             [[SafesCollection sharedInstance] save];
                         }];
}

- (void)enableOfflineCache {
    _metadata.offlineCacheAvailable = NO;
    _metadata.offlineCacheEnabled = YES;
    _metadata.offlineCacheFileIdentifier = @"";

    [[SafesCollection sharedInstance] save];
}

//////////////////////////////////////////////////////////////////////////////////////////////////////
// Operations

- (Node*)addNewRecord:(Node *_Nonnull)parentGroup {
    NSString* password = [self generatePassword];
    
    NodeFields* fields = [[NodeFields alloc] initWithUsername:@"user123"
                                                          url:@"https://strongboxsafe.com"
                                                     password:password
                                                        notes:@"Sample Database Record. You can have any text here..."];
    
    Node* record = [[Node alloc] initAsRecord:@"New Untitled Record" parent:parentGroup fields:fields];
    
    if([parentGroup addChild:record]) {
        return record;
    }
    
    return nil;
}

- (Node*)addNewGroup:(Node *_Nonnull)parentGroup title:(NSString*)title {
    Node* newGroup = [[Node alloc] initAsGroup:title parent:parentGroup];
    if( [parentGroup addChild:newGroup]) {
        return newGroup;
    }

    return nil;
}

- (void)deleteItem:(Node *_Nonnull)child {
    [child.parent removeChild:child];
}

- (BOOL)validateChangeParent:(Node *_Nonnull)parent node:(Node *_Nonnull)node {
    return [node validateChangeParent:parent];
}

- (BOOL)changeParent:(Node *_Nonnull)parent node:(Node *_Nonnull)node {
    return [node changeParent:parent];
}

- (void)defaultLastUpdateFieldsToNow {
    [self.passwordDatabase defaultLastUpdateFieldsToNow];
}

//////////////////////////////////////////////////////////////////////////////////////////////////////

- (NSString *)getMasterPassword {
    return self.passwordDatabase.masterPassword;
}

- (void)setMasterPassword:(NSString *)value {
    self.passwordDatabase.masterPassword = value;
}

-(NSDate*)lastUpdateTime {
    return self.passwordDatabase.lastUpdateTime;
}
  
-(NSString*)lastUpdateUser {
    return self.passwordDatabase.lastUpdateUser;
}

-(NSString*)lastUpdateHost {
    return self.passwordDatabase.lastUpdateHost;
}
  
-(NSString*)lastUpdateApp {
    return self.passwordDatabase.lastUpdateApp;
}
    
-(void)encrypt:(void (^)(NSData* data, NSError* error))completion {
    [SVProgressHUD showWithStatus:@"Encrypting"];
    
    dispatch_async(dispatch_get_global_queue( DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void){
        NSError* error;
        NSData* ret = [self.passwordDatabase getAsData:&error];

        dispatch_async(dispatch_get_main_queue(), ^(void){
            [SVProgressHUD dismiss];

            completion(ret, error);
        });
    });
}

////////////////////////////////////////////////////////////////////////////////////////////
// Convenience  / Helpers

- (NSSet<NSString*> *)usernameSet {
    return self.passwordDatabase.usernameSet;
}

- (NSSet<NSString*> *)passwordSet {
    return self.passwordDatabase.passwordSet;
}

- (NSString *)mostPopularUsername {
    return self.passwordDatabase.mostPopularUsername ? self.passwordDatabase.mostPopularUsername : @"";
}

- (NSString *)mostPopularPassword {
    return self.passwordDatabase.mostPopularPassword ? self.passwordDatabase.mostPopularPassword : @"";
}

- (NSString *)generatePassword {
    return [Utils generatePassword];
}

- (NSInteger) numberOfRecords {
    return self.passwordDatabase.numberOfRecords;
}

- (NSInteger) numberOfGroups {
    return self.passwordDatabase.numberOfGroups;
}

- (NSInteger) keyStretchIterations {
    return self.passwordDatabase.keyStretchIterations;
}

- (NSString*)version {
    return self.passwordDatabase.version;
}

@end
