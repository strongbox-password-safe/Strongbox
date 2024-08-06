//
//  Hybrid.m
//  Strongbox
//
//  Created by Mark on 25/09/2017.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import "iCloudSafesCoordinator.h"
#import "LocalDeviceStorageProvider.h"
#import "Strongbox.h"
#import "DatabasePreferences.h"
#import "AppPreferences.h"

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

- (BOOL)fastAvailabilityTest {
    if ( AppPreferences.sharedInstance.disableNetworkBasedFeatures ) {
        return NO;
    }
    
    return NSFileManager.defaultManager.ubiquityIdentityToken != nil;
}

- (void)initializeiCloudAccess {
    if ( AppPreferences.sharedInstance.disableNetworkBasedFeatures ) {
        return;
    }
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        _iCloudRoot = [[NSFileManager defaultManager] URLForUbiquityContainerIdentifier:kStrongboxICloudContainerIdentifier];
        
        BOOL available = (_iCloudRoot != nil);
        

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
    slog(@"local => iCloud impl [%lu]", (unsigned long)_iCloudFiles.count);
    
    self.showMigrationUi(YES);
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void) {
        NSArray<DatabasePreferences*> *localSafes = [DatabasePreferences forAllDatabasesOfProvider:kLocalDevice];
        
        for(DatabasePreferences *safe in localSafes) {
            [self migrateLocalSafeToICloud:safe];
        }
        
        self.showMigrationUi(NO);
        
        _migrationInProcessDoNotUpdateSafesCollection = NO;
    });
}

- (void)iCloudToLocalImpl {
    slog(@"iCloud => local impl  [%lu]", (unsigned long)_iCloudFiles.count);
    
    self.showMigrationUi(YES);
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void) {
        NSArray<DatabasePreferences*> *iCloudSafes = [DatabasePreferences forAllDatabasesOfProvider:kiCloud];
        
        for(DatabasePreferences *safe in iCloudSafes) {
            [self migrateICloudSafeToLocal:safe];
        }
        
        self.showMigrationUi(NO);
        _migrationInProcessDoNotUpdateSafesCollection = NO;
    });
}

- (void)migrateLocalSafeToICloud:(DatabasePreferences *)safe {
    NSURL *fileURL = [[LocalDeviceStorageProvider sharedInstance] getFileUrl:safe];
    
    NSString * displayName = safe.nickName;
    NSString * extension = [safe.fileName pathExtension];
    extension = extension ? extension : @"";
    
    NSURL *destURL = [self getFullICloudURLWithFileName:[self getUniqueICloudFilename:displayName extension:extension]];
    
    NSError * error;
    BOOL success = [[NSFileManager defaultManager] setUbiquitous:YES itemAtURL:fileURL destinationURL:destURL error:&error];
    
    if (success) {
        NSString* newNickName = [self displayNameFromUrl:destURL];
        slog(@"New Nickname = [%@] Moved %@ to %@", newNickName, fileURL, destURL);

        safe.nickName = newNickName;
        safe.storageProvider = kiCloud;
        safe.fileIdentifier = destURL.absoluteString;
        safe.fileName = [destURL lastPathComponent];
    }
    else {
        slog(@"Failed to move %@ to %@: %@", fileURL, destURL, error.localizedDescription);
    }
}

- (void)migrateICloudSafeToLocal:(DatabasePreferences *)safe {
    NSFileCoordinator* fileCoordinator = [[NSFileCoordinator alloc] initWithFilePresenter:nil];
    [fileCoordinator coordinateReadingItemAtURL:[NSURL URLWithString:safe.fileIdentifier] options:NSFileCoordinatorReadingWithoutChanges error:nil byAccessor:^(NSURL *newURL) {
        NSData* data = [NSData dataWithContentsOfURL:newURL];
      
        NSString* extension = [safe.fileName pathExtension];
        extension = extension ? extension : @"";
        
        [[LocalDeviceStorageProvider sharedInstance] create:safe.nickName
                                                   fileName:safe.fileName
                                                       data:data
                                               parentFolder:nil
                                             viewController:nil
                                                 completion:^(DatabasePreferences *metadata, NSError *error)
         {
             if (error == nil) {
                 slog(@"Copied %@ to %@", newURL, metadata.fileIdentifier);
                 
                 safe.nickName = metadata.nickName;
                 safe.storageProvider = kLocalDevice;
                 safe.fileIdentifier = metadata.fileIdentifier;
                 safe.fileName = metadata.fileName;
             }
             else {
                 slog(@"Failed to copy %@ to %@: %@", newURL, metadata.fileIdentifier, error.localizedDescription);
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
            
            
            
            [_iCloudFiles addObject:iCloudFile];
        }
    }
    
    _iCloudURLsReady = YES;
    
    if ( !_migrationInProcessDoNotUpdateSafesCollection ) {
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
        if ([[file.fileUrl lastPathComponent] compare:fileName] == NSOrderedSame) {
            nameExists = YES;
            break;
        }
    }
    return nameExists;
}

-(NSString*)getUniqueICloudFilename:(NSString *)prefix extension:(NSString*)extension {
    NSInteger docCount = 0;
    NSString* newDocName = nil;
    
    
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
    [self removeAnyDeletedICloudSafes:files];
    [self updateAnyICloudSafes:files];
    [self addAnyNewICloudSafes:files];
}

- (void)updateAnyICloudSafes:(NSArray<AppleICloudOrLocalSafeFile*> *)files {
    NSMutableDictionary<NSString*, AppleICloudOrLocalSafeFile*>* theirs = [self getAllICloudSafeFileNamesFromMetadataFilesList:files];
    NSDictionary<NSString*, DatabasePreferences*>* mine = [self getICloudSafesDictionary];
    
    for(NSString* fileName in mine.allKeys) {
        AppleICloudOrLocalSafeFile *match = [theirs objectForKey:fileName];
        
        if(match) {
            DatabasePreferences* safe = [mine objectForKey:fileName];
            
            NSString* newUrl = [match.fileUrl absoluteString];
            if ( ![safe.fileIdentifier isEqualToString:newUrl] || safe.hasUnresolvedConflicts != match.hasUnresolvedConflicts ) {
                safe.fileIdentifier = newUrl;
                safe.hasUnresolvedConflicts = match.hasUnresolvedConflicts;
            }
        }
    }
}

-(BOOL)addAnyNewICloudSafes:(NSArray<AppleICloudOrLocalSafeFile*> *)files {
    BOOL added = NO;
    
    NSMutableDictionary<NSString*, AppleICloudOrLocalSafeFile*>* theirs = [self getAllICloudSafeFileNamesFromMetadataFilesList:files];
    
    NSDictionary<NSString*, DatabasePreferences*>* mine = [self getICloudSafesDictionary];
    
    for(NSString* fileName in mine.allKeys) {
        [theirs removeObjectForKey:fileName];
    }
    
    for (AppleICloudOrLocalSafeFile* safeFile in theirs.allValues) {
        NSString *fileName = [safeFile.fileUrl lastPathComponent];
        NSString *displayName = safeFile.displayName;
        
        DatabasePreferences *newSafe = [DatabasePreferences templateDummyWithNickName:displayName storageProvider:kiCloud fileName:fileName fileIdentifier:[safeFile.fileUrl absoluteString]];
        newSafe.hasUnresolvedConflicts = safeFile.hasUnresolvedConflicts;
        
        slog(@"Got New iCloud Safe... Adding [%@]", newSafe.nickName);
      
        
        
        NSError* error;
        if ( [newSafe addWithDuplicateCheck:nil initialCacheModDate:nil error:&error] ) {
            added = YES;
        }
        else {
            slog(@"Did not add iCloud database - error = [%@]", error);
        }
    }
    
    return added;
}

- (BOOL)removeAnyDeletedICloudSafes:(NSArray<AppleICloudOrLocalSafeFile*>*)files {
    BOOL removed = NO;
    
    NSMutableDictionary<NSString*, DatabasePreferences*> *safeFileNamesToBeRemoved = [self getICloudSafesDictionary];
    NSMutableDictionary<NSString*, AppleICloudOrLocalSafeFile*>* theirs = [self getAllICloudSafeFileNamesFromMetadataFilesList:files];
    
    for(NSString* fileName in theirs.allKeys) {
        [safeFileNamesToBeRemoved removeObjectForKey:fileName];
    }
    
    for(DatabasePreferences* safe in safeFileNamesToBeRemoved.allValues) {
        slog(@"iCloud Safe Removed: %@", safe);
        [safe removeFromDatabasesList];
        removed = YES;
    }
    
    return removed;
}

-(NSMutableDictionary<NSString*, DatabasePreferences*>*)getICloudSafesDictionary {
    NSMutableDictionary<NSString*, DatabasePreferences*>* ret = [NSMutableDictionary dictionary];
    
    for( DatabasePreferences *safe in [DatabasePreferences forAllDatabasesOfProvider:kiCloud] ) {
        [ret setValue:safe forKey:safe.fileName];
    }
    
    return ret;
}

-(NSMutableDictionary<NSString*, AppleICloudOrLocalSafeFile*>*)getAllICloudSafeFileNamesFromMetadataFilesList:(NSArray<AppleICloudOrLocalSafeFile*>*)files {
    NSMutableDictionary<NSString*, AppleICloudOrLocalSafeFile*>* ret = [NSMutableDictionary dictionary];
    
    for(AppleICloudOrLocalSafeFile *item in files) {
        if(item.fileUrl && item.fileUrl.lastPathComponent) { 
            [ret setObject:item forKey:item.fileUrl.lastPathComponent];
        }
    }
    
    return ret;
}


- (void)logAllCloudStorageKeysForMetadataItem:(NSMetadataItem *)item
{


















}

- (void)logUpdateNotification:(NSNotification *)notification {
    



    NSArray* added = [notification.userInfo objectForKey:NSMetadataQueryUpdateAddedItemsKey];
    NSArray* changed = [notification.userInfo objectForKey:NSMetadataQueryUpdateChangedItemsKey];
    NSArray* removed = [notification.userInfo objectForKey:NSMetadataQueryUpdateRemovedItemsKey];








}

@end
