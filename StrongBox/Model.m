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
#import "BackupsManager.h"
#import "NSArray+Extensions.h"

@interface Model ()

@property (nonnull) NSData* lastSnapshot;
@property NSSet<NSString*> *cachedPinned;

@end

@implementation Model {
    id <SafeStorageProvider> _storageProvider;
    BOOL _cacheMode;
    BOOL _isReadOnly;
}

- (instancetype)initWithSafeDatabase:(DatabaseModel *)passwordDatabase
               originalDataForBackup:(NSData*)originalDataForBackup
                            metaData:(SafeMetaData *)metaData
                     storageProvider:(id <SafeStorageProvider>)provider
                           cacheMode:(BOOL)cacheMode
                          isReadOnly:(BOOL)isReadOnly {
    if (self = [super init]) {
        _database = passwordDatabase;
        _lastSnapshot = originalDataForBackup;
        _metadata = metaData;
        _storageProvider = provider;
        _cacheMode = cacheMode;
        _isReadOnly = isReadOnly || metaData.readOnly;
        _cachedPinned = [NSSet setWithArray:self.metadata.favourites];
        
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

- (void)update:(BOOL)isAutoFill handler:(void(^)(BOOL, NSError * _Nullable error))handler {
    if (!_cacheMode && !_isReadOnly) {
        [self encrypt:^(BOOL userCancelled, NSData * _Nullable data, NSError * _Nullable error) {
            if (userCancelled || data == nil || error) {
                handler(userCancelled, error);
                return;
            }

            if(self.lastSnapshot) { // Dummy Database => will be nil
                if(![BackupsManager.sharedInstance writeBackup:self.lastSnapshot metadata:self.metadata]) {
                    NSString* em = NSLocalizedString(@"model_error_cannot_write_backup", @"Could not write backup, will not proceed with write of database!");
                    NSError* err = [Utils createNSError:em errorCode:-1];
                    handler(NO, err);
                    return;
                }
                self.lastSnapshot = data;
            }
                        
            [self->_storageProvider update:self.metadata
                                      data:data
                                isAutoFill:isAutoFill
                                completion:^(NSError *error) {
                              if(!error) {
                                  [self updateOfflineCacheWithData:data];
                                  [self updateAutoFillCacheWithData:data];
                                  [self updateAutoFillQuickTypeDatabase];
                              }
                              handler(NO, error);
                          }];
        }];
    }
    else {
        if(_isReadOnly) {
            handler(NO, [Utils createNSError:NSLocalizedString(@"model_error_readonly_cannot_write", @"You are in read-only mode. Cannot Write!") errorCode:-1]);
        }
        else {
            handler(NO, [Utils createNSError:NSLocalizedString(@"model_error_offline_cannot_write", @"You are currently in offline mode. The database cannot be modified.") errorCode:-1]);
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
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void) {
            [self.database getAsData:^(BOOL userCancelled, NSData * _Nullable data, NSError * _Nullable error) {
                dispatch_async(dispatch_get_main_queue(), ^(void) {
                    if (data != nil) {
                        [self saveAutoFillCacheFile:data safe:self.metadata];
                    }
                    handler();
                });
            }];
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

//- (void)updateOfflineCache:(void (^)(void))handler {
//    if (self.isCloudBasedStorage && !self.isUsingOfflineCache && _metadata.offlineCacheEnabled) {
//        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void) {
//            [self.database getAsData:^(BOOL userCancelled, NSData * _Nullable data, NSError * _Nullable error) {
//                dispatch_async(dispatch_get_main_queue(), ^(void) {
//                    if (data != nil) {
//                        [self saveOfflineCacheFile:data safe:self->_metadata];
//                    }
//
//                    handler();
//                });
//            }];
//        });
//    }
//}

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
    BOOL keePassGroupTitleRules = self.database.format != kPasswordSafe;
    
    Node* newGroup = [[Node alloc] initAsGroup:title parent:parentGroup keePassGroupTitleRules:keePassGroupTitleRules uuid:nil];
    if([parentGroup addChild:newGroup keePassGroupTitleRules:keePassGroupTitleRules]) {
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
        
        return [child changeParent:self.database.recycleBinNode keePassGroupTitleRules:YES];
    }
    else {
        [child.parent removeChild:child];
        return YES;
    }
}

// Pinned or Not?

- (NSSet<NSString*>*)pinnedSet {
    return self.cachedPinned;
}

- (BOOL)isPinned:(Node*)item {
    if(self.cachedPinned.count == 0) {
        return NO;
    }
    
    NSString* sid = [item getSerializationId:self.database.format != kPasswordSafe];
    
    return [self.cachedPinned containsObject:sid];
}

- (void)togglePin:(Node*)item {
    NSString* sid = [item getSerializationId:self.database.format != kPasswordSafe];

    NSMutableSet<NSString*>* favs = self.cachedPinned.mutableCopy;
    
    if([self isPinned:item]) {
        [favs removeObject:sid];
    }
    else {
        [favs addObject:sid];
    }
    
    // Trim - by search DB and mapping back...
    
    NSArray<Node*>* pinned = [self.database.rootGroup filterChildren:YES predicate:^BOOL(Node * _Nonnull node) {
        NSString* sid = [node getSerializationId:self.database.format != kPasswordSafe];
        return [favs containsObject:sid];
    }];
    
    NSArray<NSString*>* trimmed = [pinned map:^id _Nonnull(Node * _Nonnull obj, NSUInteger idx) {
        return [obj getSerializationId:self.database.format != kPasswordSafe];
    }];
    self.cachedPinned = [NSSet setWithArray:trimmed];

    self.metadata.favourites = trimmed;
    [SafesList.sharedInstance update:self.metadata];
}

//////////////////////////////////////////////////////////////////////////////////////////////////////

-(void)encrypt:(void (^)(BOOL userCancelled, NSData* data, NSError* error))completion {
    [SVProgressHUD showWithStatus:NSLocalizedString(@"generic_encrypting", @"Encrypting")];
    
    dispatch_async(dispatch_get_global_queue( DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void){
        [self.database getAsData:^(BOOL userCancelled, NSData * _Nullable data, NSError * _Nullable error) {
            dispatch_async(dispatch_get_main_queue(), ^(void){
                [SVProgressHUD dismiss];
                completion(userCancelled, data, error);
            });
        }];
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
