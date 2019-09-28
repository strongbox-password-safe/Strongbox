//
//  BackupsManager.m
//  Strongbox-iOS
//
//  Created by Mark on 26/09/2019.
//  Copyright © 2019 Mark McGuill. All rights reserved.
//

#import "BackupsManager.h"
#import "FileManager.h"
#import "Utils.h"

@implementation BackupsManager

+ (instancetype)sharedInstance {
    static BackupsManager *sharedInstance = nil;
    static dispatch_once_t onceToken;
    
    dispatch_once(&onceToken, ^{
        sharedInstance = [[BackupsManager alloc] init];
    });
    
    return sharedInstance;
}

- (BOOL)writeBackup:(NSData *)data metadata:(SafeMetaData *)metadata {
    if(metadata.makeBackups) {
        NSString* filename = [NSString stringWithFormat:@"%@.bak", iso8601DateString(NSDate.date)];

        NSURL* url = [metadata.backupsDirectory URLByAppendingPathComponent:filename];

        NSError* error;
        BOOL success = [data writeToURL:url options:kNilOptions error:&error];
        if(!success) {
            NSLog(@"Error saving backup: [%@]", error);
            return NO;
        }
    }
    
    [self trimBackups:metadata];
    
    return YES;
}

- (void)deleteAllBackups:(SafeMetaData*)metadata {
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

- (NSArray<BackupItem*>*)getAvailableBackups:(SafeMetaData*)metadata {
    NSError* error;
    
    NSArray<NSURLResourceKey>* keys = @[NSURLCreationDateKey, NSURLFileSizeKey];
    
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
            NSNumber* fileSize = attributesDictionary[NSURLFileSizeKey];
            
            [ret addObject:[BackupItem withUrl:file date:dateCreate fileSize:fileSize]];
            NSLog(@"Found file with create date: [%@] Size: [%@]", dateCreate, friendlyFileSizeString(fileSize.unsignedIntegerValue));
        }
        else {
            NSLog(@"Error getting attributes for file: [%@]", file);
        }
    }
    
    return [ret sortedArrayUsingComparator:^NSComparisonResult(BackupItem*  _Nonnull obj1, BackupItem*  _Nonnull obj2) {
        return [obj2.date compare:obj1.date];
    }];
}

- (void)trimBackups:(SafeMetaData*)metadata {
    NSArray* backups = [self getAvailableBackups:metadata];
    
    if(backups.count > metadata.maxBackupKeepCount) {
        NSArray* toBeTrimmed = [backups subarrayWithRange:NSMakeRange(metadata.maxBackupKeepCount, backups.count - metadata.maxBackupKeepCount)];
     
        //NSLog(@"To be trimmed Backups: %@", toBeTrimmed);
        
        for (BackupItem* backup in toBeTrimmed) {
            [self deleteBackup:backup];
        }
    }
}

@end
