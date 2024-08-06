//
//  BackupsManager.m
//  Strongbox-iOS
//
//  Created by Mark on 26/09/2019.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import "BackupsManager.h"

#if TARGET_OS_IPHONE
#import "StrongboxiOSFilesManager.h"
#else
#import "StrongboxMacFilesManager.h"
#endif

#import "Utils.h"
#import "NSDate+Extensions.h"

#if !TARGET_OS_IPHONE
#import "Settings.h"
#endif

@implementation BackupsManager

+ (instancetype)sharedInstance {
    static BackupsManager *sharedInstance = nil;
    static dispatch_once_t onceToken;
    
    dispatch_once(&onceToken, ^{
        sharedInstance = [[BackupsManager alloc] init];
    });
    
    return sharedInstance;
}

- (BOOL)writeBackup:(NSURL *)snapshot metadata:(METADATA_PTR)metadata {
#if !TARGET_OS_IPHONE
    if ( !Settings.sharedInstance.makeLocalRollingBackups ) {
        return YES;
    }
#endif
    
    if ( metadata.makeBackups ) {
        NSDate* now = NSDate.date;
        NSString* filename = [NSString stringWithFormat:@"%@.bak", now.fileNameCompatibleDateTimePrecise];

        NSURL* dir = metadata.backupsDirectory; 
        if(!dir) {
            slog(@"Error saving backup");
            return NO;
        }

        NSURL* url = [metadata.backupsDirectory URLByAppendingPathComponent:filename];


        
        NSError* error;
        BOOL success = [NSFileManager.defaultManager copyItemAtURL:snapshot toURL:url error:&error];
        if(!success) {
            slog(@"Error saving backup: [%@]-[%@]", error, url);
            return NO;
        }
        
        
        
        
        [NSFileManager.defaultManager setAttributes:@{ NSFileCreationDate : now } ofItemAtPath:url.path error:&error];
        if(!success) {
            slog(@"Error saving backup: [%@]", error);
            return NO;
        }
    }
    
    [self trimBackups:metadata];
    
    return YES;
}

- (void)deleteAllBackups:(METADATA_PTR)metadata {
    NSArray* backups = [self getAvailableBackups:metadata all:NO];
    
    for (BackupItem* backup in backups) {
        [self deleteBackup:backup];
    }
}

- (void)deleteBackup:(BackupItem *)item {
    NSError* error;
    
    if(![NSFileManager.defaultManager removeItemAtURL:item.url error:&error]) {
        slog(@"Error Deleting Backup: [%@]", error);
    }
}

- (NSArray<BackupItem*> *)getAvailableBackups:(METADATA_PTR)metadata all:(BOOL)all {
    if ( metadata != nil ) {
        return [self getAvailableBackupsForDatabase:metadata];
    }
    else {
        if ( all ) {
            return [self getAllEmergencyRecoveryFilesAsBackups];
        }
        else {
            return [self getAllAvailableBackups]; 
        }
    }
}

- (NSArray<BackupItem*> *)getAllEmergencyRecoveryFilesAsBackups {
#if TARGET_OS_IPHONE
    NSArray<BackupItem*>* appSupport = [self getAllAvailableFilesAsBackupsAtDir:StrongboxFilesManager.sharedInstance.appSupportDirectory];
    NSArray<BackupItem*>* documents = [self getAllAvailableFilesAsBackupsAtDir:StrongboxFilesManager.sharedInstance.documentsDirectory];
#endif
    
    NSArray<BackupItem*>* sharedAppGroup = [self getAllAvailableFilesAsBackupsAtDir:StrongboxFilesManager.sharedInstance.sharedAppGroupDirectory recursive:NO];
    NSArray<BackupItem*>* syncManager = [self getAllAvailableFilesAsBackupsAtDir:StrongboxFilesManager.sharedInstance.syncManagerLocalWorkingCachesDirectory recursive:YES];

    NSMutableArray<BackupItem*>* ret = [NSMutableArray arrayWithArray:sharedAppGroup];
    [ret addObjectsFromArray:syncManager];

#if TARGET_OS_IPHONE
    [ret addObjectsFromArray:appSupport];
    [ret addObjectsFromArray:documents];
#endif
    
    return ret;
}




- (NSArray<BackupItem*> *)getAllAvailableBackups {
    NSURL* dir = StrongboxFilesManager.sharedInstance.backupFilesDirectory;

    return [self getAllAvailableFilesAsBackupsAtDir:dir];
}

- (NSArray<BackupItem*> *)getAllAvailableFilesAsBackupsAtDir:(NSURL*)dir {
    return [self getAllAvailableFilesAsBackupsAtDir:dir recursive:YES];
}

- (NSArray<BackupItem*> *)getAllAvailableFilesAsBackupsAtDir:(NSURL*)dir recursive:(BOOL)recursive {
    NSArray<NSURLResourceKey>* keys = @[NSURLCreationDateKey, NSURLContentModificationDateKey, NSURLFileSizeKey, NSURLIsDirectoryKey];
    NSUInteger flags = NSDirectoryEnumerationSkipsPackageDescendants | NSDirectoryEnumerationSkipsHiddenFiles;

    if ( !recursive ) {
        flags |= NSDirectoryEnumerationSkipsSubdirectoryDescendants;
    }
    
    NSMutableArray<BackupItem*>* ret = [NSMutableArray array];


    NSDirectoryEnumerator<NSURL *> * enumerator = [NSFileManager.defaultManager enumeratorAtURL:dir
                                                                     includingPropertiesForKeys:keys
                                                                                        options:flags
                                                                                   errorHandler:nil];
    
    for (NSURL *url in enumerator) {
        NSError* error;
        NSDictionary* attributesDictionary = [url resourceValuesForKeys:keys error:&error];
        if(attributesDictionary) {
            NSDate* dateCreate = attributesDictionary[NSURLCreationDateKey];
            NSDate* modDate = attributesDictionary[NSURLContentModificationDateKey];
            NSNumber* fileSize = attributesDictionary[NSURLFileSizeKey];
            NSNumber* isDirectory = attributesDictionary[NSURLIsDirectoryKey];
            
            if ( !isDirectory.boolValue ) {


                [ret addObject:[BackupItem withUrl:url backupCreatedDate:dateCreate modDate:modDate fileSize:fileSize]];
            }
        }
        else {
            slog(@"Error getting attributes for file: [%@]", url);
        }
    }

    return [ret sortedArrayUsingComparator:^NSComparisonResult(BackupItem*  _Nonnull obj1, BackupItem*  _Nonnull obj2) {
        return [obj2.backupCreatedDate compare:obj1.backupCreatedDate];
    }];
}

- (NSArray<BackupItem*> *)getAvailableBackupsForDatabase:(METADATA_PTR)metadata {
    NSURL* dir = metadata.backupsDirectory; 
    if(!dir) {
        slog(@"Could not get backup directory");

        return @[];
    }

    NSArray<NSURLResourceKey>* keys = @[NSURLCreationDateKey, NSURLContentModificationDateKey, NSURLFileSizeKey, NSURLIsDirectoryKey];
    NSUInteger flags = NSDirectoryEnumerationSkipsPackageDescendants | NSDirectoryEnumerationSkipsHiddenFiles | NSDirectoryEnumerationSkipsSubdirectoryDescendants;
    NSError* error;
    NSArray<NSURL*> *files = [NSFileManager.defaultManager contentsOfDirectoryAtURL:dir
                                                         includingPropertiesForKeys:keys
                                                                            options:flags
                                                                              error:&error];

    if(!files) {
        slog(@"Could not get files at backup path");
        return @[];
    }
    
    NSMutableArray<BackupItem*>* ret = [NSMutableArray arrayWithCapacity:files.count];
    
    for (NSURL* file in files) {
        NSDictionary* attributesDictionary = [file resourceValuesForKeys:keys error:&error];
        if(attributesDictionary) {
            NSDate* dateCreate = attributesDictionary[NSURLCreationDateKey];
            NSDate* modDate = attributesDictionary[NSURLContentModificationDateKey];
            NSNumber* fileSize = attributesDictionary[NSURLFileSizeKey];
            NSNumber* isDirectory = attributesDictionary[NSURLIsDirectoryKey];
            
            if ( !isDirectory.boolValue ) {


                [ret addObject:[BackupItem withUrl:file backupCreatedDate:dateCreate modDate:modDate fileSize:fileSize]];
            }
        }
        else {
            slog(@"Error getting attributes for file: [%@]", file);
        }
    }
    
    return [ret sortedArrayUsingComparator:^NSComparisonResult(BackupItem*  _Nonnull obj1, BackupItem*  _Nonnull obj2) {
        return [obj2.backupCreatedDate compare:obj1.backupCreatedDate];
    }];
}

- (void)trimBackups:(METADATA_PTR)metadata {
    NSArray* backups = [self getAvailableBackups:metadata all:NO];
    
    if(backups.count > metadata.maxBackupKeepCount) {
        NSArray* toBeTrimmed = [backups subarrayWithRange:NSMakeRange(metadata.maxBackupKeepCount, backups.count - metadata.maxBackupKeepCount)];
     
        
        
        for (BackupItem* backup in toBeTrimmed) {
            [self deleteBackup:backup];
        }
    }
}

@end
