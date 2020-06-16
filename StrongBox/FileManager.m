//
//  FileManager.m
//  Strongbox
//
//  Created by Mark on 17/06/2019.
//  Copyright © 2019 Mark McGuill. All rights reserved.
//

#import "FileManager.h"
#import "SafesList.h"
#import "DatabaseModel.h"
#import "SharedAppAndAutoFillSettings.h"

@interface FileManager ()

@end

@implementation FileManager

+ (instancetype)sharedInstance {
    static FileManager *sharedInstance = nil;
    static dispatch_once_t onceToken;
    
    dispatch_once(&onceToken, ^{
        sharedInstance = [[FileManager alloc] init];
    });
    
    return sharedInstance;
}

- (NSURL *)documentsDirectory {
    NSURL* ret = [[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory
                                                        inDomains:NSUserDomainMask].lastObject;
    
    [self createIfNecessary:ret];
    
    return ret;
}

- (NSURL *)offlineCacheDirectory {
    NSURL *ret =  [[NSFileManager defaultManager] URLsForDirectory:NSApplicationSupportDirectory
                                                  inDomains:NSUserDomainMask].lastObject;
    
    [self createIfNecessary:ret];
    
    return ret;
}

- (NSURL *)autoFillCacheDirectory {
    NSURL* url = FileManager.sharedInstance.sharedAppGroupDirectory;
    NSURL* ret = [url URLByAppendingPathComponent:@"auto-fill-caches"];
    
    [self createIfNecessary:ret];
    
    return ret;
}

- (NSURL *)keyFilesDirectory {
    NSURL* url = [[NSFileManager defaultManager] containerURLForSecurityApplicationGroupIdentifier:SharedAppAndAutoFillSettings.sharedInstance.appGroupName];
    if(!url) {
        NSLog(@"Could not get container URL for App Group: [%@]", SharedAppAndAutoFillSettings.sharedInstance.appGroupName);
        return nil;
    }
    
    NSURL* ret = [url URLByAppendingPathComponent:@"key-files"];
    
    [self createIfNecessary:ret];
    
    return ret;
}

- (NSURL *)backupFilesDirectory {
    NSURL* url = [[NSFileManager defaultManager] containerURLForSecurityApplicationGroupIdentifier:SharedAppAndAutoFillSettings.sharedInstance.appGroupName];
    if(!url) {
        NSLog(@"Could not get container URL for App Group: [%@]", SharedAppAndAutoFillSettings.sharedInstance.appGroupName);
        return nil;
    }
    
    NSURL* ret = [url URLByAppendingPathComponent:@"backups"];
    
    [self createIfNecessary:ret];
    
    return ret;
}

- (NSURL *)preferencesDirectory {
    NSURL* url = [[NSFileManager defaultManager] containerURLForSecurityApplicationGroupIdentifier:SharedAppAndAutoFillSettings.sharedInstance.appGroupName];
    if(!url) {
        NSLog(@"Could not get container URL for App Group: [%@]", SharedAppAndAutoFillSettings.sharedInstance.appGroupName);
        return nil;
    }

    NSURL* ret = [url URLByAppendingPathComponent:@"preferences"];

    [self createIfNecessary:ret];

    return ret;
}

- (NSURL *)sharedAppGroupDirectory {
    NSURL* url = [[NSFileManager defaultManager] containerURLForSecurityApplicationGroupIdentifier:SharedAppAndAutoFillSettings.sharedInstance.appGroupName];
    if(!url) {
        NSLog(@"Could not get container URL for App Group: [%@]", SharedAppAndAutoFillSettings.sharedInstance.appGroupName);
        return nil;
    }
    
    [self createIfNecessary:url];
    
    return url;
}

- (void)createIfNecessary:(NSURL*)url {
    NSError* error;
    if (![[NSFileManager defaultManager] createDirectoryAtURL:url withIntermediateDirectories:YES attributes:nil error:&error]) {
        NSLog(@"Error Creating Directory: %@ => [%@]", url, error.localizedDescription);
    }
}

- (void)excludeDirectoriesFromBackup {
    [self excludeFromBackup:self.documentsDirectory];
    [self excludeFromBackup:self.offlineCacheDirectory];
    [self excludeFromBackup:self.sharedAppGroupDirectory];
    [self excludeFromBackup:self.keyFilesDirectory];
    [self excludeFromBackup:self.autoFillCacheDirectory];
    [self excludeFromBackup:self.backupFilesDirectory];
}

- (void)excludeFromBackup:(NSURL*)URL {
    NSError *error = nil;
    
    BOOL success = [URL setResourceValue:[NSNumber numberWithBool:YES]
                                  forKey:NSURLIsExcludedFromBackupKey
                                   error:&error];
    if(!success){
        NSLog(@"Error excluding %@ from backup %@", [URL lastPathComponent], error);
    }
}

- (void)deleteAllLocalAndAppGroupFiles {
    [self deleteAllInDirectory:self.documentsDirectory];
    [self deleteAllInDirectory:self.offlineCacheDirectory];
    [self deleteAllInDirectory:self.sharedAppGroupDirectory];
    [self deleteAllInDirectory:self.keyFilesDirectory];
    [self deleteAllInDirectory:self.autoFillCacheDirectory];
    [self deleteAllInDirectory:self.backupFilesDirectory];
}

- (void)deleteAllInDirectory:(NSURL*)url {
    NSLog(@"Deleting Files at [%@]", url);
    
    NSFileManager *fm = [NSFileManager defaultManager];
    
    NSString *directory = url.path;
    NSError *error = nil;
    for (NSString *file in [fm contentsOfDirectoryAtPath:directory error:&error]) {
        NSString* path = [NSString pathWithComponents:@[directory, file]];
        
        NSLog(@"Removing File: [%@]", path);
        
        BOOL success = [fm removeItemAtPath:path error:&error];
        if (!success || error) {
            NSLog(@"Failed to remove [%@]: [%@]", file, error);
        }
    }
}

- (void)deleteAllInboxItems {
    NSFileManager *fm = [NSFileManager defaultManager];
    
    NSURL* url = [self.documentsDirectory URLByAppendingPathComponent:@"Inbox"];
    
    NSString *directory = url.path;
    NSError *error = nil;
    for (NSString *file in [fm contentsOfDirectoryAtPath:directory error:&error]) {
        NSString* path = [NSString pathWithComponents:@[directory, file]];
        
        NSLog(@"Removing Inbox File: [%@]", path);
        
        BOOL success = [fm removeItemAtPath:path error:&error];
        if (!success || error) {
            NSLog(@"Failed to remove [%@]: [%@]", file, error);
        }
    }
}

@end
