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
#import "PasswordGenerator.h"
#import "Settings.h"

@implementation Model {
    id <SafeStorageProvider> _storageProvider;
    BOOL _cacheMode;
    BOOL _isReadOnly;
}

- (instancetype)initWithSafeDatabase:(DatabaseModel *)passwordDatabase
                            metaData:(SafeMetaData *)metaData
                     storageProvider:(id <SafeStorageProvider>)provider
                           cacheMode:(BOOL)cacheMode
                          isReadOnly:(BOOL)isReadOnly {
    if (self = [super init]) {
        _database = passwordDatabase;
        _metadata = metaData;
        _storageProvider = provider;
        _cacheMode = cacheMode;
        _isReadOnly = isReadOnly;

        return self;
    }
    else {
        return nil;
    }
}

- (BOOL)isCloudBasedStorage {
    return _storageProvider.cloudBased;
}

- (BOOL)isUsingOfflineCache {
    return _cacheMode;
}

- (BOOL)isReadOnly {
    return _isReadOnly;
}

- (void)update:(void (^)(NSError *error))handler {
    if (!_cacheMode && !_isReadOnly) {
        [self encrypt:^(NSData * _Nullable updatedSafeData, NSError * _Nullable error) {
            if (updatedSafeData == nil) {
                handler(error);
                return;
            }

            [self->_storageProvider update:self.metadata
                                data:updatedSafeData
                          completion:^(NSError *error) {
                              [self updateOfflineCacheWithData:updatedSafeData];
                              [self updateAutoFillCacheWithData:updatedSafeData];
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

- (void)updateAutoFillCacheWithData:(NSData *)data {
    if (self.metadata.autoFillCacheEnabled) {
        [self saveAutoFillCacheFile:data safe:self.metadata];
    }
}

- (void)updateAutoFillCache:(void (^_Nonnull)(void))handler {
    if (self.metadata.autoFillCacheEnabled) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void)
        {
           NSError *error;
           NSData *updatedSafeData = [self.database getAsData:&error];
           
           dispatch_async(dispatch_get_main_queue(), ^(void) {
               if (updatedSafeData != nil) {
                   [self saveAutoFillCacheFile:updatedSafeData safe:self.metadata];
               }
               
               handler();
           });
        });
    }
}

- (void)disableAndClearAutoFillCache {
    [[LocalDeviceStorageProvider sharedInstance] deleteAutoFillCache:_metadata completion:^(NSError *error) {
          self.metadata.autoFillCacheEnabled = NO;
          self.metadata.autoFillCacheAvailable = NO;
          
          [[SafesList sharedInstance] update:self.metadata];
      }];
}

- (void)enableAutoFillCache {
    _metadata.autoFillCacheAvailable = NO;
    _metadata.autoFillCacheEnabled = YES;
    
    [[SafesList sharedInstance] update:self.metadata];
}

- (void)updateOfflineCache:(void (^)(void))handler {
    if (self.isCloudBasedStorage && !self.isUsingOfflineCache && _metadata.offlineCacheEnabled) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void)
        {
            NSError *error;
            NSData *updatedSafeData = [self.database getAsData:&error];

            dispatch_async(dispatch_get_main_queue(), ^(void) {
                if (updatedSafeData != nil && self->_metadata.offlineCacheEnabled) {
                    [self saveOfflineCacheFile:updatedSafeData safe:self->_metadata];
                }

                handler();
            });
        });
    }
}

- (void)updateOfflineCacheWithData:(NSData *)data {
    if (self.isCloudBasedStorage && !self.isUsingOfflineCache && _metadata.offlineCacheEnabled) {
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
                                    completion:^(BOOL success) {
                                        [self  onStoredOfflineCacheFile:safe
                                                                success:success];
                                    }];
    }
    else {
        [[LocalDeviceStorageProvider sharedInstance] createOfflineCacheFile:safe data:data completion:^(BOOL success) {
            [self onStoredOfflineCacheFile:safe success:success];
        }];
    }
}

- (void)saveAutoFillCacheFile:(NSData *)data
                         safe:(SafeMetaData *)safe {
    if (safe.autoFillCacheAvailable) {
        [[LocalDeviceStorageProvider sharedInstance] updateAutoFillCache:safe
                                                                        data:data
                                                              viewController:nil
                                                                  completion:^(BOOL success) {
          [self  onStoredAutoFillCacheFile:safe success:success];
      }];
    }
    else {
        [[LocalDeviceStorageProvider sharedInstance] createAutoFillCache:safe data:data completion:^(BOOL success) {
            [self onStoredAutoFillCacheFile:safe success:success];
        }];
    }
}

- (void)onStoredAutoFillCacheFile:(SafeMetaData *)safe success:(BOOL)success {
    if (!success) {
        NSLog(@"Error updating Autofill Cache file.");
        
        safe.autoFillCacheAvailable = NO;
    }
    else {
        //NSLog(@"Offline Cache Now Available.");
        
        safe.autoFillCacheAvailable = YES;
    }
    
    [[SafesList sharedInstance] update:safe];
}

- (void)onStoredOfflineCacheFile:(SafeMetaData *)safe success:(BOOL)success {
    if (!success) {
        NSLog(@"Error updating Offline Cache file.");

        safe.offlineCacheAvailable = NO;
    }
    else {
        //NSLog(@"Offline Cache Now Available.");

        safe.offlineCacheAvailable = YES;
    }

    [[SafesList sharedInstance] update:safe];
}

- (void)disableAndClearOfflineCache {
    [[LocalDeviceStorageProvider sharedInstance] deleteOfflineCachedSafe:_metadata
                         completion:^(NSError *error) {
                             self->_metadata.offlineCacheEnabled = NO;
                             self->_metadata.offlineCacheAvailable = NO;

                             [[SafesList sharedInstance] update:self.metadata];
                         }];
}

- (void)enableOfflineCache {
    _metadata.offlineCacheAvailable = NO;
    _metadata.offlineCacheEnabled = YES;

    [[SafesList sharedInstance] update:self.metadata];
}

//////////////////////////////////////////////////////////////////////////////////////////////////////
// Operations

- (Node*)addNewGroup:(Node *_Nonnull)parentGroup title:(NSString*)title {
    Node* newGroup = [[Node alloc] initAsGroup:title parent:parentGroup uuid:nil];
    if([parentGroup addChild:newGroup]) {
        return newGroup;
    }

    return nil;
}

- (void)deleteItem:(Node *_Nonnull)child {
    [child.parent removeChild:child];
}

//////////////////////////////////////////////////////////////////////////////////////////////////////

-(void)encrypt:(void (^)(NSData* data, NSError* error))completion {
    [SVProgressHUD showWithStatus:@"Encrypting"];
    
    dispatch_async(dispatch_get_global_queue( DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void){
        NSError* error;
        NSData* ret = [self.database getAsData:&error];

        dispatch_async(dispatch_get_main_queue(), ^(void){
            [SVProgressHUD dismiss];

            completion(ret, error);
        });
    });
}

- (NSString *)generatePassword {
    PasswordGenerationParameters *params = [[Settings sharedInstance] passwordGenerationParameters];
    
    return [PasswordGenerator generatePassword:params];
}

@end
