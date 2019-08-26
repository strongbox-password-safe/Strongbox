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
#import "Settings.h"
#import "AutoFillManager.h"
#import "CacheManager.h"
#import "PasswordMaker.h"

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
        _isReadOnly = isReadOnly || metaData.readOnly;

        return self;
    }
    else {
        return nil;
    }
}

- (BOOL)isCloudBasedStorage {
    return _storageProvider.allowOfflineCache;
}

- (BOOL)isUsingOfflineCache {
    return _cacheMode;
}

- (BOOL)isReadOnly {
    return _isReadOnly;
}

- (void)update:(BOOL)isAutoFill handler:(void (^)(NSError * _Nullable))handler {
    if (!_cacheMode && !_isReadOnly) {
        [self encrypt:^(NSData * _Nullable updatedSafeData, NSError * _Nullable error) {
            if (updatedSafeData == nil) {
                handler(error);
                return;
            }

            [self->_storageProvider update:self.metadata
                                      data:updatedSafeData
                                isAutoFill:isAutoFill
                                completion:^(NSError *error) {
                              if(!error) {
                                  [self updateOfflineCacheWithData:updatedSafeData];
                                  [self updateAutoFillCacheWithData:updatedSafeData];
                                  [self updateAutoFillQuickTypeDatabase];
                              }
                              handler(error);
                          }];
        }];
    }
    else {
        if(_isReadOnly) {
            handler([Utils createNSError:NSLocalizedString(@"model_error_readonly_cannot_write", @"You are in read-only mode. Cannot Write!") errorCode:-1]);
        }
        else {
            handler([Utils createNSError:NSLocalizedString(@"model_error_offline_cannot_write", @"You are currently in offline mode. The database cannot be modified.") errorCode:-1]);
        }
    }
}

- (void)updateAutoFillCacheWithData:(NSData *)data {
    if (self.metadata.autoFillEnabled) {
        [self saveAutoFillCacheFile:data safe:self.metadata];
    }
}

- (void)updateAutoFillCache:(void (^_Nonnull)(void))handler {
    if (self.metadata.autoFillEnabled) {
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

- (void)disableAndClearAutoFill {
    [[CacheManager sharedInstance] deleteAutoFillCache:_metadata completion:^(NSError *error) {
          self.metadata.autoFillEnabled = NO;
          self.metadata.autoFillCacheAvailable = NO;
        
          [AutoFillManager.sharedInstance clearAutoFillQuickTypeDatabase];
        
          [[SafesList sharedInstance] update:self.metadata];
      }];
}

- (void)enableAutoFill {
    _metadata.autoFillCacheAvailable = NO;
    _metadata.autoFillEnabled = YES;
    
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

- (void)saveOfflineCacheFile:(NSData *)data safe:(SafeMetaData *)safe {
    [[CacheManager sharedInstance] updateOfflineCachedSafe:safe data:data completion:^(BOOL success) {
        if (!success) {
            NSLog(@"Error updating Offline Cache file.");
        }

        safe.offlineCacheAvailable = success;
        [[SafesList sharedInstance] update:safe];
    }];
}

- (void)saveAutoFillCacheFile:(NSData *)data safe:(SafeMetaData *)safe {
      [[CacheManager sharedInstance] updateAutoFillCache:safe data:data completion:^(BOOL success) {
          if (!success) {
              NSLog(@"Error updating Autofill Cache file.");
          }

          safe.autoFillCacheAvailable = success;
          [[SafesList sharedInstance] update:safe];
      }];
}

//- (void)disableAndClearOfflineCache {
//    [[CacheManager sharedInstance] deleteOfflineCachedSafe:_metadata
//                         completion:^(NSError *error) {
//                             self->_metadata.offlineCacheEnabled = NO;
//                             self->_metadata.offlineCacheAvailable = NO;
//
//                             [[SafesList sharedInstance] update:self.metadata];
//                         }];
//}
//
//- (void)enableOfflineCache {
//    _metadata.offlineCacheAvailable = NO;
//    _metadata.offlineCacheEnabled = YES;
//
//    [[SafesList sharedInstance] update:self.metadata];
//}

//////////////////////////////////////////////////////////////////////////////////////////////////////
// Operations

- (Node*)addNewGroup:(Node *_Nonnull)parentGroup title:(NSString*)title {
    BOOL allowDuplicateGroupTitles = self.database.format != kPasswordSafe;
    
    Node* newGroup = [[Node alloc] initAsGroup:title parent:parentGroup allowDuplicateGroupTitles:allowDuplicateGroupTitles uuid:nil];
    if([parentGroup addChild:newGroup allowDuplicateGroupTitles:allowDuplicateGroupTitles]) {
        return newGroup;
    }

    return nil;
}

- (BOOL)deleteWillRecycle:(Node*_Nonnull)child {
    BOOL willRecycle = self.database.recycleBinEnabled;
    if(self.database.recycleBinEnabled && self.database.recycleBinNode) {
        if([self.database.recycleBinNode contains:child] || self.database.recycleBinNode == child) {
            willRecycle = NO;
        }
    }

    return willRecycle;
}

- (BOOL)deleteItem:(Node *_Nonnull)child {
    if([self deleteWillRecycle:child]) {
        // UUID is NIL/Non Existent or Zero? - Create
        if(self.database.recycleBinNode == nil) {
            [self.database createNewRecycleBinNode];
        }
        
        return [child changeParent:self.database.recycleBinNode allowDuplicateGroupTitles:YES];
    }
    else {
        [child.parent removeChild:child];
        return YES;
    }
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
    PasswordGenerationConfig* config = Settings.sharedInstance.passwordGenerationConfig;
    return [PasswordMaker.sharedInstance generateForConfigOrDefault:config];
}

- (void)updateAutoFillQuickTypeDatabase {
    if(self.metadata.autoFillEnabled) {
        [AutoFillManager.sharedInstance updateAutoFillQuickTypeDatabase:self.database databaseUuid:self.metadata.uuid];
    }
}

@end
