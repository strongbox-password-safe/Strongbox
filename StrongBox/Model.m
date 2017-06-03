//
//  SafeViewModel.m
//  StrongBox
//
//  Created by Mark McGuill on 20/06/2014.
//  Copyright (c) 2014 Mark McGuill. All rights reserved.
//

#import "Model.h"
#import "Utils.h"
#import "SafeItemViewModel.h"

@interface Model ()

@end

@implementation Model {
    id <SafeStorageProvider> _storageProvider;
    LocalDeviceStorageProvider *_local;
    BOOL _isUsingOfflineCache;
}

- (BOOL)isCloudBasedStorage {
    return _storageProvider.cloudBased;
}

- (BOOL)isUsingOfflineCache {
    return _isUsingOfflineCache;
}

- (instancetype)initWithSafeDatabase:(SafeDatabase *)safe
                            metaData:(SafeMetaData *)metaData
                     storageProvider:(id <SafeStorageProvider>)provider
                   usingOfflineCache:(BOOL)usingOfflineCache
                localStorageProvider:(LocalDeviceStorageProvider *)local
                               safes:(SafesCollection *)safes; {
    if (self = [super init]) {
        _safe = safe;
        _coreModel = [[CoreModel alloc] initWithSafeDatabase:safe];
        _metadata = metaData;
        _storageProvider = provider;
        _isUsingOfflineCache = usingOfflineCache;
        _local = local;
        _safes = safes;

        return self;
    }
    else {
        return nil;
    }
}

- (void)update:(void (^)(NSError *error))handler {
    if (!_isUsingOfflineCache) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void)
        {
            NSData *updatedSafeData = [self.safe getAsData];

            dispatch_async(dispatch_get_main_queue(), ^(void) {
                if (updatedSafeData == nil) {
                    handler([Utils createNSError:@"Could not get safe as data." errorCode:-1]);
                    return;
                }

                [_storageProvider update:self.metadata
                                    data:updatedSafeData
                              completion:^(NSError *error) {
                                  [self updateOfflineCacheWithData:updatedSafeData];
                                  handler(error);
                              }];
            });
        });
    }
    else {
        NSLog(@"Attempt to write a read-only safe!");
        [NSException raise:@"Attempt to write a read-only safe!" format:@"foo of is invalid", nil];
    }
}

- (void)updateOfflineCache:(void (^)())handler {
    if (self.isCloudBasedStorage && !self.isUsingOfflineCache && _metadata.offlineCacheEnabled) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void)
        {
            NSData *updatedSafeData = [self.safe getAsData];

            dispatch_async(dispatch_get_main_queue(), ^(void) {
                if (updatedSafeData != nil && _metadata.offlineCacheEnabled) {
                    NSLog(@"Updating offline cache for safe.");
                    [self saveOfflineCacheFile:updatedSafeData safe:_metadata localProvider:_local];
                }

                handler();
            });
        });
    }
}

- (void)updateOfflineCacheWithData:(NSData *)data {
    if (self.isCloudBasedStorage && !self.isUsingOfflineCache && _metadata.offlineCacheEnabled) {
        NSLog(@"Updating offline cache for safe.");
        [self saveOfflineCacheFile:data safe:_metadata localProvider:_local];
    }
}

- (void)saveOfflineCacheFile:(NSData *)data safe:(SafeMetaData *)safe localProvider:(LocalDeviceStorageProvider *)localProvider {
    // Store this safe locally
    // Do we already have a file?
    //      Yes-> Overwrite
    //      No-> Create New & Set location

    if (safe.offlineCacheAvailable) {
        [localProvider updateOfflineCachedSafe:safe
                                          data:data
                                viewController:nil
                                    completion:^(NSError *error) {
                                        [self  onStoredOfflineCacheFile:safe
                                        error:error];
                                    }];
    }
    else {
        // Create File Identifer

        safe.offlineCacheFileIdentifier = [[NSUUID alloc] init].UUIDString;

        [localProvider create:safe.offlineCacheFileIdentifier
                         data:data
                 parentFolder:nil
               viewController:nil
                   completion:^(SafeMetaData *metadata, NSError *error) {
                       [self  onStoredOfflineCacheFile:safe
                                      error:error];
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

    [self.safes save];
}

- (void)disableAndClearOfflineCache {
    [_local deleteOfflineCachedSafe:_metadata
                         completion:^(NSError *error) {
                             _metadata.offlineCacheEnabled = NO;
                             _metadata.offlineCacheAvailable = NO;
                             _metadata.offlineCacheFileIdentifier = @"";

                             [self.safes save];
                         }];
}

- (void)enableOfflineCache {
    _metadata.offlineCacheAvailable = NO;
    _metadata.offlineCacheEnabled = YES;
    _metadata.offlineCacheFileIdentifier = @"";

    [self.safes save];
}

//////////////////////////////////////////////////////////////////////////////////////////////////////
// Search

- (NSArray *)getSearchableItems {
    return [self.coreModel getSearchableItems];
}

/////////////////////////////////////////////////////////////////////////////////////////////////////////
// Regular Displayable Items

- (NSArray *)getSubgroupsForGroup:(Group *)group {
    return [self.coreModel getSubgroupsForGroup:group];
}

- (NSArray *)getItemsForGroup:(Group *)group {
    return [self.coreModel getItemsForGroup:group withFilter:nil];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (BOOL)validateMoveItems:(NSArray *)items destination:(Group *)group {
    return [self.coreModel validateMoveItems:items destination:group];
}

- (BOOL)validateMoveItems:(NSArray *)items destination:(Group *)group checkIfMoveIntoSubgroupOfDestinationOk:(BOOL)checkIfMoveIntoSubgroupOfDestinationOk {
    return [self.coreModel validateMoveItems:items destination:group checkIfMoveIntoSubgroupOfDestinationOk:checkIfMoveIntoSubgroupOfDestinationOk];
}

- (void)moveItems:(NSArray *)items destination:(Group *)group {
    return [self.coreModel moveItems:items destination:group];
}

- (void)deleteItems:(NSArray *)items {
    return [self.coreModel deleteItems:items];
}

////////////////////////////////////////////////////////////////////////////////////////////
// Auto complete helper

- (NSSet *)getAllExistingUserNames {
    return self.coreModel.getAllExistingUserNames;
}

- (NSSet *)getAllExistingPasswords {
    return self.coreModel.getAllExistingPasswords;
}

- (NSString *)getMostPopularUsername {
    return self.coreModel.getMostPopularUsername;
}

- (NSString *)getMostPopularPassword {
    return self.coreModel.getMostPopularPassword;
}

- (NSString *)generatePassword {
    return self.coreModel.generatePassword;
}

@end
