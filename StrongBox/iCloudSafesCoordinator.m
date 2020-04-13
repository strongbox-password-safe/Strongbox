//
//  Hybrid.m
//  Strongbox
//
//  Created by Mark on 25/09/2017.
//  Copyright © 2017 Mark McGuill. All rights reserved.
//

#import "iCloudSafesCoordinator.h"
#import "Settings.h"
#import "AppleICloudProvider.h"
#import "LocalDeviceStorageProvider.h"
#import "Strongbox.h"
#import "SafesList.h"

@implementation iCloudSafesCoordinator

NSURL * _iCloudRoot;
NSMetadataQuery * _query;
BOOL _iCloudURLsReady;
NSMutableArray<AppleICloudOrLocalSafeFile*> * _iCloudFiles;
BOOL _pleaseCopyiCloudToLocalWhenReady;
BOOL _pleaseMoveLocalToiCloudWhenReady;
BOOL _migrationInProcessDoNotUpdateSafesCollection;

+ (instancetype)sharedInstance {
    static iCloudSafesCoordinator *sharedInstance = nil;
    static dispatch_once_t onceToken;
    
    dispatch_once(&onceToken, ^{
        sharedInstance = [[iCloudSafesCoordinator alloc] init];
    });
    
    return sharedInstance;
}

- (instancetype)init {
    if(self = [super init]) {
        _iCloudFiles = [[NSMutableArray alloc] init];
    }

    return self;
}

- (void)initializeiCloudAccessWithCompletion:(void (^)(BOOL available)) completion {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        _iCloudRoot = [[NSFileManager defaultManager] URLForUbiquityContainerIdentifier:kStrongboxICloudContainerIdentifier];
        if (_iCloudRoot != nil) {
            dispatch_async(dispatch_get_main_queue(), ^{
                //NSLog(@"iCloud available at: %@", _iCloudRoot);
                completion(TRUE);
            });
        }
        else {
            dispatch_async(dispatch_get_main_queue(), ^{
                //NSLog(@"iCloud not available");
                completion(FALSE);
            });
        }
    });
}

- (NSURL *)iCloudDocumentsFolder {
    if (_iCloudRoot) {
        return [_iCloudRoot URLByAppendingPathComponent:@"Documents" isDirectory:YES];
    }
    else {
        return nil;
    }
}

- (void)migrateLocalToiCloud:(void (^)(BOOL show)) completion {
    self.showMigrationUi = completion;
    _migrationInProcessDoNotUpdateSafesCollection = YES;
    
    if (_iCloudURLsReady) {
        [self localToiCloudImpl];
    }
    else {
        _pleaseMoveLocalToiCloudWhenReady = YES;
    }
}

- (void)migrateiCloudToLocal:(void (^)(BOOL show)) completion {
    self.showMigrationUi = completion;
    _migrationInProcessDoNotUpdateSafesCollection = YES;
    
    if (_iCloudURLsReady) {
        [self iCloudToLocalImpl];
    }
    else {
        _pleaseCopyiCloudToLocalWhenReady = YES;
    }
}

- (void)localToiCloudImpl {
    NSLog(@"local => iCloud impl [%lu]", (unsigned long)_iCloudFiles.count);
    
    self.showMigrationUi(YES);
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void) {
        NSArray<SafeMetaData*> *localSafes = [SafesList.sharedInstance getSafesOfProvider:kLocalDevice];
        
        for(SafeMetaData *safe in localSafes) {
            [self migrateLocalSafeToICloud:safe];
            [SafesList.sharedInstance update:safe];
        }
        
        self.showMigrationUi(NO);
//        self.onSafesCollectionUpdated();
        
        _migrationInProcessDoNotUpdateSafesCollection = NO;
    });
}

- (void)iCloudToLocalImpl {
    NSLog(@"iCloud => local impl  [%lu]", (unsigned long)_iCloudFiles.count);
    
    self.showMigrationUi(YES);
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void) {
        NSArray<SafeMetaData*> *iCloudSafes = [SafesList.sharedInstance getSafesOfProvider:kiCloud];
        
        for(SafeMetaData *safe in iCloudSafes) {
            [self migrateICloudSafeToLocal:safe];
            [SafesList.sharedInstance update:safe];
        }
        
        self.showMigrationUi(NO);
//        self.onSafesCollectionUpdated();
        
        _migrationInProcessDoNotUpdateSafesCollection = NO;
    });
}

- (void)migrateLocalSafeToICloud:(SafeMetaData *)safe {
    NSURL *fileURL = [[LocalDeviceStorageProvider sharedInstance] getFileUrl:safe];
    
    NSString * displayName = safe.nickName;
    NSString * extension = [safe.fileName pathExtension];
    extension = extension ? extension : @"";
    
    NSURL *destURL = [self getFullICloudURLWithFileName:[self getUniqueICloudFilename:displayName extension:extension]];
    
    NSError * error;
    BOOL success = [[NSFileManager defaultManager] setUbiquitous:[Settings sharedInstance].iCloudOn itemAtURL:fileURL destinationURL:destURL error:&error];
    
    if (success) {
        NSString* newNickName = [self displayNameFromUrl:destURL];
        NSLog(@"New Nickname = [%@] Moved %@ to %@", newNickName, fileURL, destURL);

        safe.nickName = newNickName;
        safe.storageProvider = kiCloud;
        safe.fileIdentifier = destURL.absoluteString;
        safe.fileName = [destURL lastPathComponent];
    }
    else {
        NSLog(@"Failed to move %@ to %@: %@", fileURL, destURL, error.localizedDescription);
    }
}

- (void)migrateICloudSafeToLocal:(SafeMetaData *)safe {
    NSFileCoordinator* fileCoordinator = [[NSFileCoordinator alloc] initWithFilePresenter:nil];
    [fileCoordinator coordinateReadingItemAtURL:[NSURL URLWithString:safe.fileIdentifier] options:NSFileCoordinatorReadingWithoutChanges error:nil byAccessor:^(NSURL *newURL) {
        NSData* data = [NSData dataWithContentsOfURL:newURL];
      
        NSString* extension = [safe.fileName pathExtension];
        extension = extension ? extension : @"";
        
        [[LocalDeviceStorageProvider sharedInstance] create:safe.nickName
                                                  extension:extension
                                                       data:data
                                               parentFolder:nil
                                             viewController:nil
                                                 completion:^(SafeMetaData *metadata, NSError *error)
         {
             if (error == nil) {
                 NSLog(@"Copied %@ to %@ (%d)", newURL, metadata.fileIdentifier, [Settings sharedInstance].iCloudOn);
                 
                 safe.nickName = metadata.nickName;
                 safe.storageProvider = kLocalDevice;
                 safe.fileIdentifier = metadata.fileIdentifier;
                 safe.fileName = metadata.fileName;
             }
             else {
                 NSLog(@"Failed to copy %@ to %@: %@", newURL, metadata.fileIdentifier, error.localizedDescription);
             }
         }];
    }];
}

- (NSMetadataQuery *)documentQuery {
    NSMetadataQuery * query = [[NSMetadataQuery alloc] init];
    
    if (query) {
        [query setSearchScopes:[NSArray arrayWithObject:NSMetadataQueryUbiquitousDocumentsScope]];
        
        [query setPredicate:[NSPredicate predicateWithFormat:@"%K LIKE %@",
                             NSMetadataItemFSNameKey, @"*"]];
    }
    
    return query;
}

- (void)stopQuery {
    if (_query) {
        //NSLog(@"No longer watching iCloud dir...");
        
        [[NSNotificationCenter defaultCenter] removeObserver:self name:NSMetadataQueryDidFinishGatheringNotification object:nil];
        [[NSNotificationCenter defaultCenter] removeObserver:self name:NSMetadataQueryDidUpdateNotification object:nil];
        [_query stopQuery];
        _query = nil;
    }
}

- (void)startQuery {
    [self stopQuery];
    
    _iCloudURLsReady = NO;
    [_iCloudFiles removeAllObjects];
    
    //NSLog(@"Starting to watch iCloud dir...");
    
    _query = [self documentQuery];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(onICloudUpdateNotification:)
                                                 name:NSMetadataQueryDidFinishGatheringNotification
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(onICloudUpdateNotification:)
                                                 name:NSMetadataQueryDidUpdateNotification
                                               object:nil];
    
    [_query startQuery];
}

- (NSString*)displayNameFromUrl:(NSURL*)url {
    return [[url.lastPathComponent stringByDeletingPathExtension] stringByRemovingPercentEncoding];
}

- (void)onICloudUpdateNotification:(NSNotification *)notification {
    [_query disableUpdates];
    [_iCloudFiles removeAllObjects];
    
    [self logUpdateNotification:notification];
    
    NSArray<NSMetadataItem*> * queryResults = [_query results];
    
    for (NSMetadataItem * result in queryResults) {
        [self logAllCloudStorageKeysForMetadataItem:result];
        
        // Don't include hidden files or directories
        
        NSNumber * hidden = nil;
        NSURL * fileURL = [result valueForAttribute:NSMetadataItemURLKey];
        BOOL success = [fileURL getResourceValue:&hidden forKey:NSURLIsHiddenKey error:nil];
        BOOL isHidden = (success && [hidden boolValue]);
        
        NSNumber *isDirectory;
        success = [fileURL getResourceValue:&isDirectory forKey:NSURLIsDirectoryKey error:nil];
        BOOL isDir = (success && [isDirectory boolValue]);
        
        if (!isHidden && !isDir) {
            NSString* displayName = [result valueForAttribute:NSMetadataItemDisplayNameKey];
            NSString* dn = displayName ? displayName : [self displayNameFromUrl:fileURL];
            
            NSNumber *hasUnresolvedConflicts = [result valueForAttribute:NSMetadataUbiquitousItemHasUnresolvedConflictsKey];
            BOOL huc = hasUnresolvedConflicts != nil ? [hasUnresolvedConflicts boolValue] : NO;
            
            AppleICloudOrLocalSafeFile* iCloudFile = [[AppleICloudOrLocalSafeFile alloc] initWithDisplayName:dn fileUrl:fileURL hasUnresolvedConflicts:huc];
            
            //NSLog(@"Found on iCloud: %@", iCloudFile);
            
            [_iCloudFiles addObject:iCloudFile];
        }
    }
    
    _iCloudURLsReady = YES;
    
    if ([Settings sharedInstance].iCloudOn && !_migrationInProcessDoNotUpdateSafesCollection) {
        [self syncICloudUpdateWithSafesCollection:_iCloudFiles];
    }

    if (_pleaseMoveLocalToiCloudWhenReady) {
        _pleaseMoveLocalToiCloudWhenReady = NO;
        [self localToiCloudImpl];
    }
    else if (_pleaseCopyiCloudToLocalWhenReady) {
        _pleaseCopyiCloudToLocalWhenReady = NO;
        [self iCloudToLocalImpl];
    }
    
    [_query enableUpdates];
}

- (NSURL *)getFullICloudURLWithFileName:(NSString *)filename {
    NSURL * docsDir = [_iCloudRoot URLByAppendingPathComponent:@"Documents" isDirectory:YES];
    return [docsDir URLByAppendingPathComponent:filename];
}

- (BOOL)fileNameExistsInICloud:(NSString *)fileName {
    BOOL nameExists = NO;
    for (AppleICloudOrLocalSafeFile *file in _iCloudFiles) {
        if ([[file.fileUrl lastPathComponent] isEqualToString:fileName]) {
            nameExists = YES;
            break;
        }
    }
    return nameExists;
}

-(NSString*)getUniqueICloudFilename:(NSString *)prefix extension:(NSString*)extension {
    NSInteger docCount = 0;
    NSString* newDocName = nil;
    
    // At this point, the document list should be up-to-date.
    BOOL done = NO;
    BOOL first = YES;
    while (!done) {
        if (first) {
            first = NO;
            newDocName = [NSString stringWithFormat:@"%@.%@",
                          prefix, extension];
        } else {
            newDocName = [NSString stringWithFormat:@"%@ %ld.%@",
                          prefix, (long)docCount, extension];
        }
        
        BOOL nameExists = [self fileNameExistsInICloud:newDocName];
        
        if (!nameExists) {
            break;
        } else {
            docCount++;
        }
    }
    
    return newDocName;
}

- (void)syncICloudUpdateWithSafesCollection:(NSArray<AppleICloudOrLocalSafeFile*>*)files {
    BOOL removed = [self removeAnyDeletedICloudSafes:files];
    BOOL updated = [self updateAnyICloudSafes:files];
    BOOL added = [self addAnyNewICloudSafes:files];
    
    if(added || removed || updated) {
        // This is now done via NSNotificationCenter
        // self.onSafesCollectionUpdated();
    }
}

- (BOOL)updateAnyICloudSafes:(NSArray<AppleICloudOrLocalSafeFile*> *)files {
    BOOL updated = NO;
    
    NSMutableDictionary<NSString*, AppleICloudOrLocalSafeFile*>* theirs = [self getAllICloudSafeFileNamesFromMetadataFilesList:files];
    NSDictionary<NSString*, SafeMetaData*>* mine = [self getICloudSafesDictionary];
    
    for(NSString* fileName in mine.allKeys) {
        AppleICloudOrLocalSafeFile *match = [theirs objectForKey:fileName];
        
        if(match) {
            SafeMetaData* safe = [mine objectForKey:fileName];
            safe.fileIdentifier = [match.fileUrl absoluteString];
            safe.hasUnresolvedConflicts = match.hasUnresolvedConflicts;
            updated = YES;
            [SafesList.sharedInstance update:safe];
        }
    }
    
    return updated;
}

-(BOOL)addAnyNewICloudSafes:(NSArray<AppleICloudOrLocalSafeFile*> *)files {
    BOOL added = NO;
    
    NSMutableDictionary<NSString*, AppleICloudOrLocalSafeFile*>* theirs = [self getAllICloudSafeFileNamesFromMetadataFilesList:files];
    
    NSDictionary<NSString*, SafeMetaData*>* mine = [self getICloudSafesDictionary];
    
    for(NSString* fileName in mine.allKeys) {
        [theirs removeObjectForKey:fileName];
    }
    
    for (AppleICloudOrLocalSafeFile* safeFile in theirs.allValues) {
        NSString *fileName = [safeFile.fileUrl lastPathComponent];
        NSString *displayName = safeFile.displayName;
        
        SafeMetaData *newSafe = [[SafeMetaData alloc] initWithNickName:displayName storageProvider:kiCloud fileName:fileName fileIdentifier:[safeFile.fileUrl absoluteString]];
        newSafe.hasUnresolvedConflicts = safeFile.hasUnresolvedConflicts;
        
        NSLog(@"Got New iCloud Safe... Adding [%@]", newSafe.nickName);
        
        [[SafesList sharedInstance] addWithDuplicateCheck:newSafe];
        
        added = YES;
    }
    
    return added;
}

- (BOOL)removeAnyDeletedICloudSafes:(NSArray<AppleICloudOrLocalSafeFile*>*)files {
    BOOL removed = NO;
    
    NSMutableDictionary<NSString*, SafeMetaData*> *safeFileNamesToBeRemoved = [self getICloudSafesDictionary];
    NSMutableDictionary<NSString*, AppleICloudOrLocalSafeFile*>* theirs = [self getAllICloudSafeFileNamesFromMetadataFilesList:files];
    
    for(NSString* fileName in theirs.allKeys) {
        [safeFileNamesToBeRemoved removeObjectForKey:fileName];
    }
    
    for(SafeMetaData* safe in safeFileNamesToBeRemoved.allValues) {
        NSLog(@"iCloud Safe Removed: %@", safe);
        
        [SafesList.sharedInstance remove:safe.uuid];
        removed = YES;
    }
    
    return removed;
}

-(NSMutableDictionary<NSString*, SafeMetaData*>*)getICloudSafesDictionary {
    NSMutableDictionary<NSString*, SafeMetaData*>* ret = [NSMutableDictionary dictionary];
    
    for(SafeMetaData *safe in [[SafesList sharedInstance] getSafesOfProvider:kiCloud]) {
        [ret setValue:safe forKey:safe.fileName];
    }
    
    return ret;
}

-(NSMutableDictionary<NSString*, AppleICloudOrLocalSafeFile*>*)getAllICloudSafeFileNamesFromMetadataFilesList:(NSArray<AppleICloudOrLocalSafeFile*>*)files {
    NSMutableDictionary<NSString*, AppleICloudOrLocalSafeFile*>* ret = [NSMutableDictionary dictionary];
    
    for(AppleICloudOrLocalSafeFile *item in files) {
        if(item.fileUrl && item.fileUrl.lastPathComponent) { // There was a crash here somehow... so protect against
            [ret setObject:item forKey:item.fileUrl.lastPathComponent];
        }
    }
    
    return ret;
}


- (void)logAllCloudStorageKeysForMetadataItem:(NSMetadataItem *)item
{
//    NSString* displayName = [item valueForAttribute:NSMetadataItemDisplayNameKey];
//    NSDate* contentChangeDate = [item valueForAttribute:NSMetadataItemFSContentChangeDateKey];
//    NSNumber *isUbiquitous = [item valueForAttribute:NSMetadataItemIsUbiquitousKey];
//    NSNumber *hasUnresolvedConflicts = [item valueForAttribute:NSMetadataUbiquitousItemHasUnresolvedConflictsKey];
//    NSNumber *downloadStatus = [item valueForAttribute:NSMetadataUbiquitousItemDownloadingStatusKey];
//    NSNumber *isUploaded = [item valueForAttribute:NSMetadataUbiquitousItemIsUploadedKey];
//    NSNumber *isUploading = [item valueForAttribute:NSMetadataUbiquitousItemIsUploadingKey];
//    NSNumber *percentDownloaded = [item valueForAttribute:NSMetadataUbiquitousItemPercentDownloadedKey];
//    NSNumber *percentUploaded = [item valueForAttribute:NSMetadataUbiquitousItemPercentUploadedKey];
//    NSURL *url = [item valueForAttribute:NSMetadataItemURLKey];
//
//    NSNumber * hidden = nil;
//    [url getResourceValue:&hidden forKey:NSURLIsHiddenKey error:nil];
//
//    //BOOL documentExists = [[NSFileManager defaultManager] fileExistsAtPath:[url path]];
//
//    NSLog(@"%@ change:%@ hidden:%@ isUbiquitous:%@ hasUnresolvedConflicts:%@ downloadStatus:%@(%@%%) isUploaded:%@ isUploading:%@ (%@%%) - %@",
//          displayName, contentChangeDate, hidden, isUbiquitous, hasUnresolvedConflicts, downloadStatus, percentDownloaded, isUploaded, isUploading, percentUploaded, url);
}

- (void)logUpdateNotification:(NSNotification *)notification {
    //The query reports all files found, every time.
//
//    NSLog(@"*********************************************************************************************************");
//
//    NSArray* added = [notification.userInfo objectForKey:NSMetadataQueryUpdateAddedItemsKey];
//    NSArray* changed = [notification.userInfo objectForKey:NSMetadataQueryUpdateChangedItemsKey];
//    NSArray* removed = [notification.userInfo objectForKey:NSMetadataQueryUpdateRemovedItemsKey];
//
//    NSLog(@"+%lu /%lu -%lu", (unsigned long)added.count, (unsigned long)changed.count, (unsigned long)removed.count);
//
//    for(NSMetadataItem *item in changed) {
//        NSLog(@"Changed: %@", item);
//    }
//
//    NSLog(@"*********************************************************************************************************");
}

@end
