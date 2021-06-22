//
//  BackupsManager.m
//  Strongbox-iOS
//
//  Created by Mark on 26/09/2019.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import "BackupsManager.h"
#import "FileManager.h"
#import "Utils.h"
#import "NSDate+Extensions.h"

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
    if(metadata.makeBackups) {
        NSDate* now = NSDate.date;
        NSString* filename = [NSString stringWithFormat:@"%@.bak", now.fileNameCompatibleDateTimePrecise];

        NSURL* url = [metadata.backupsDirectory URLByAppendingPathComponent:filename];

        NSLog(@"Creating Backup [%@]", url);
        
        NSError* error;
        BOOL success = [NSFileManager.defaultManager copyItemAtURL:snapshot toURL:url error:&error];
        if(!success) {
            NSLog(@"Error saving backup: [%@]-[%@]", error, url);
            return NO;
        }
        
        
        
        
        [NSFileManager.defaultManager setAttributes:@{ NSFileCreationDate : now } ofItemAtPath:url.path error:&error];
        if(!success) {
            NSLog(@"Error saving backup: [%@]", error);
            return NO;
        }
    }
    
    [self trimBackups:metadata];
    
    return YES;
}

- (void)deleteAllBackups:(METADATA_PTR)metadata {
    NSArray* backups = [self getAvailableBackups:metadata];
    
    for (BackupItem* backup in backups) {
        [self deleteBackup:backup];
    }
}

- (void)deleteBackup:(BackupItem *)item {
    NSError* error;
    
    if(![NSFileManager.defaultManager removeItemAtURL:item.url error:&error]) {
        NSLog(@"Error Deleting Backup: [%@]", error);
    }
}

- (NSArray<BackupItem *> *)getAvailableBackups:(METADATA_PTR)metadata {
    NSError* error;
    
    NSArray<NSURLResourceKey>* keys = @[NSURLCreationDateKey, NSURLContentModificationDateKey, NSURLFileSizeKey];
    
    NSArray<NSURL*> *files = [NSFileManager.defaultManager contentsOfDirectoryAtURL:metadata.backupsDirectory
                                                         includingPropertiesForKeys:keys
                                                                            options:NSDirectoryEnumerationSkipsSubdirectoryDescendants |
                                                                                    NSDirectoryEnumerationSkipsPackageDescendants   |
                                                                                    NSDirectoryEnumerationSkipsHiddenFiles
                                                                              error:&error];

    if(!files) {
        NSLog(@"Could not get files at backup path");
        return @[];
    }
    
    NSMutableArray<BackupItem*>* ret = [NSMutableArray arrayWithCapacity:files.count];
    
    for (NSURL* file in files) {
        NSDictionary* attributesDictionary = [file resourceValuesForKeys:keys error:&error];
        if(attributesDictionary) {
            NSDate* dateCreate = attributesDictionary[NSURLCreationDateKey];
            NSDate* modDate = attributesDictionary[NSURLContentModificationDateKey];
            NSNumber* fileSize = attributesDictionary[NSURLFileSizeKey];
            
            [ret addObject:[BackupItem withUrl:file backupCreatedDate:dateCreate modDate:modDate fileSize:fileSize]];

        }
        else {
            NSLog(@"Error getting attributes for file: [%@]", file);
        }
    }
    
    return [ret sortedArrayUsingComparator:^NSComparisonResult(BackupItem*  _Nonnull obj1, BackupItem*  _Nonnull obj2) {
        return [obj2.backupCreatedDate compare:obj1.backupCreatedDate];
    }];
}

- (void)trimBackups:(METADATA_PTR)metadata {
    NSArray* backups = [self getAvailableBackups:metadata];
    
    if(backups.count > metadata.maxBackupKeepCount) {
        NSArray* toBeTrimmed = [backups subarrayWithRange:NSMakeRange(metadata.maxBackupKeepCount, backups.count - metadata.maxBackupKeepCount)];
     
        
        
        for (BackupItem* backup in toBeTrimmed) {
            [self deleteBackup:backup];
        }
    }
}

@end
