//
//  FileManager.m
//  Strongbox
//
//  Created by Mark on 17/06/2019.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import "FileManager.h"
#import "DatabasePreferences.h"
#import "DatabaseModel.h"
#import "AppPreferences.h"

static NSString* const kEncAttachmentDirectoryName = @"_strongbox_enc_att";
static NSString* const kEncryptionStreamDirectoryName = @"_enc_stream";

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

- (NSURL *)archivedCrashFile {
    return [self.appSupportDirectory URLByAppendingPathComponent:@"last-crash.json"];
}

- (NSURL *)crashFile {
    return [self.documentsDirectory URLByAppendingPathComponent:@"crash.json"];
}

- (NSURL *)appSupportDirectory {
    NSURL *ret =  [[NSFileManager defaultManager] URLsForDirectory:NSApplicationSupportDirectory
                                                  inDomains:NSUserDomainMask].lastObject;
    
    [self createIfNecessary:ret];
    
    return ret;
}

- (NSURL *)syncManagerLocalWorkingCachesDirectory {
    NSURL* url = FileManager.sharedInstance.sharedAppGroupDirectory;
    NSURL* ret = [url URLByAppendingPathComponent:@"sync-manager/local"];
    
    [self createIfNecessary:ret];
    
    return ret;
}

- (NSURL *)syncManagerMergeWorkingDirectory {
    NSURL* url = FileManager.sharedInstance.sharedAppGroupDirectory;
    NSURL* ret = [url URLByAppendingPathComponent:@"sync-manager/merge-working"];
    
    [self createIfNecessary:ret];
    
    return ret;
}

- (NSURL *)keyFilesDirectory {
    NSURL* url = FileManager.sharedInstance.sharedAppGroupDirectory;
    NSURL* ret = [url URLByAppendingPathComponent:@"key-files"];
    
    [self createIfNecessary:ret];
    
    return ret;
}

- (NSURL *)backupFilesDirectory {
    NSURL* url = FileManager.sharedInstance.sharedAppGroupDirectory;
    NSURL* ret = [url URLByAppendingPathComponent:@"backups"];
    
    [self createIfNecessary:ret];
    
    return ret;
}

- (NSURL *)preferencesDirectory {
    NSURL* url = FileManager.sharedInstance.sharedAppGroupDirectory;
    NSURL* ret = [url URLByAppendingPathComponent:@"preferences"];

    [self createIfNecessary:ret];

    return ret;
}

- (NSURL *)sharedAppGroupDirectory {
    NSURL* url = [[NSFileManager defaultManager] containerURLForSecurityApplicationGroupIdentifier:AppPreferences.sharedInstance.appGroupName];
    if(!url) {
        NSLog(@"Could not get container URL for App Group: [%@]", AppPreferences.sharedInstance.appGroupName);
        return nil;
    }
    
    [self createIfNecessary:url];
    
    return url;
}

- (NSURL*)sharedLocalDeviceDatabasesDirectory { 
    NSURL* url = FileManager.sharedInstance.sharedAppGroupDirectory;
    NSURL* ret = [url URLByAppendingPathComponent:@"local-databases"];

    [self createIfNecessary:ret];

    return ret;
}

- (void)createIfNecessary:(NSURL*)url {
    NSError* error;
    if (![[NSFileManager defaultManager] createDirectoryAtURL:url withIntermediateDirectories:YES attributes:nil error:&error]) {
        NSLog(@"Error Creating Directory: %@ => [%@]", url, error.localizedDescription);
    }
}

- (void)setFileProtection:(BOOL)complete {
    [self setFileProtectionRecursive:self.documentsDirectory complete:complete];
    [self setFileProtectionRecursive:self.sharedAppGroupDirectory complete:complete];
    [self setFileProtectionRecursive:self.appSupportDirectory complete:complete];
}

- (void)setFileProtectionRecursive:(NSURL*)url complete:(BOOL)complete {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSURL *directoryURL = url;
    NSArray *keys = @[NSURLIsDirectoryKey, NSURLFileProtectionKey];

    NSDirectoryEnumerator *enumerator = [fileManager enumeratorAtURL:directoryURL
                                          includingPropertiesForKeys:keys
                                                             options:0
                                                        errorHandler:^BOOL(NSURL *url, NSError *error) {
        NSLog(@"Error Traversing Directory: [%@]", error);
        return YES; 
    }];

    for (NSURL *url in enumerator) {


     




            




            [self setFileProtectionForFile:url complete:complete];

            






    }
}

- (void)setFileProtectionForFile:(NSURL*)URL complete:(BOOL)complete {
    NSError *error = nil;
    
    NSFileProtectionType prot = complete ? NSURLFileProtectionComplete : NSURLFileProtectionCompleteUntilFirstUserAuthentication;
    
    BOOL success = [URL setResourceValue:prot forKey:NSURLFileProtectionKey error:&error];

    if(!success){
        NSLog(@"Error setting File Protection for %@ - %@", [URL lastPathComponent], error);
    }
    else {
        NSLog(@"%@ [%@] file protection set", complete ? @"Complete" : @"Default", URL.lastPathComponent);
    }
}



- (void)setDirectoryInclusionFromBackup:(BOOL)localDocuments importedKeyFiles:(BOOL)importedKeyFiles {
    
    
    [self setIncludeExcludeFromBackup:self.syncManagerLocalWorkingCachesDirectory include:NO];
    
    
    
    [self setIncludeExcludeFromBackup:self.documentsDirectory include:localDocuments];
    [self setIncludeExcludeFromBackup:self.sharedLocalDeviceDatabasesDirectory include:localDocuments];
            
    
    
    [self setIncludeExcludeSharedLocalFilesFromBackup:self.sharedAppGroupDirectory include:localDocuments];
    
    [self setIncludeExcludeFromBackup:self.backupFilesDirectory include:localDocuments];
    [self setIncludeExcludeFromBackup:self.preferencesDirectory include:localDocuments];

    
    
    [self setIncludeExcludeFromBackup:self.keyFilesDirectory include:importedKeyFiles];
}

- (void)setIncludeExcludeSharedLocalFilesFromBackup:(NSURL*)URL include:(BOOL)include {
    NSArray<NSURL*>* sharedAppGroupContents = [[NSFileManager defaultManager] contentsOfDirectoryAtURL:URL
                                                                  includingPropertiesForKeys:@[NSURLIsDirectoryKey]
                                                                                     options:NSDirectoryEnumerationSkipsSubdirectoryDescendants |
                                                                                             NSDirectoryEnumerationSkipsPackageDescendants   |
                                                                                             NSDirectoryEnumerationSkipsHiddenFiles
                                                                                       error:NULL];
    
    for (NSURL *file in sharedAppGroupContents) {
        NSError *error;
        NSNumber *isDirectory = nil;
        if (![file getResourceValue:&isDirectory forKey:NSURLIsDirectoryKey error:&error]) {
            
            NSLog(@"%@", error);
        }
        else if (![isDirectory boolValue]) {
            [self setIncludeExcludeFromBackup:file include:include];
        }
    }
}

- (void)setIncludeExcludeFromBackup:(NSURL*)URL include:(BOOL)include {
    NSError *error = nil;
    
    BOOL success = [URL setResourceValue:[NSNumber numberWithBool:!include]
                                  forKey:NSURLIsExcludedFromBackupKey
                                   error:&error];
    if(!success){
        NSLog(@"Error setting include/exclude %@ from backup %@", [URL lastPathComponent], error);
    }
    else {

    }
}

- (void)deleteAllLocalAndAppGroupFiles {
    [self deleteAllInDirectory:self.documentsDirectory];
    [self deleteAllInDirectory:self.sharedLocalDeviceDatabasesDirectory];
    [self deleteAllInDirectory:self.keyFilesDirectory];
    [self deleteAllInDirectory:self.backupFilesDirectory];
    [self deleteAllInDirectory:self.preferencesDirectory];
    [self deleteAllInDirectory:self.syncManagerLocalWorkingCachesDirectory];
    [self deleteAllInDirectory:self.sharedAppGroupDirectory recursive:NO]; 
}

- (void)deleteAllInDirectory:(NSURL*)url {
    [self deleteAllInDirectory:url recursive:YES];
}

- (void)deleteAllInDirectory:(NSURL*)url recursive:(BOOL)recursive {
    NSLog(@"Deleting Files at [%@]", url);
    
    NSFileManager *fm = [NSFileManager defaultManager];
    
    NSString *directory = url.path;
    NSError *error = nil;
    NSArray<NSString*> *files = [fm contentsOfDirectoryAtPath:directory error:&error];
    
    if (error) {
        NSLog(@"Error reading contents of directory [%@]", error);
        return;
    }
    
    for (NSString *file in files) {
        NSString* path = [NSString pathWithComponents:@[directory, file]];
        
        BOOL isDirectory;
        if ([NSFileManager.defaultManager fileExistsAtPath:path isDirectory:&isDirectory]) {
            if (recursive || !isDirectory) {
                NSLog(@"Removing File: [%@]", path);
                
                BOOL success = [fm removeItemAtPath:path error:&error];
                if (!success || error) {
                    NSLog(@"Failed to remove [%@]: [%@]", file, error);
                }
            }
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

- (NSString *)tmpEncryptionStreamPath {
    NSString *ret =  [NSTemporaryDirectory() stringByAppendingPathComponent:kEncryptionStreamDirectoryName];
    NSError* error;
    
    if (![[NSFileManager defaultManager] createDirectoryAtPath:ret withIntermediateDirectories:YES attributes:nil error:&error]) {
        NSLog(@"Error Creating Directory: %@ => [%@]", ret, error.localizedDescription);
    }

    return ret;
}

- (NSString *)tmpEncryptedAttachmentPath {
    NSString *ret =  [NSTemporaryDirectory() stringByAppendingPathComponent:kEncAttachmentDirectoryName];
    NSError* error;
    
    if (![[NSFileManager defaultManager] createDirectoryAtPath:ret withIntermediateDirectories:YES attributes:nil error:&error]) {
        NSLog(@"Error Creating Directory: %@ => [%@]", ret, error.localizedDescription);
    }

    return ret;
}

- (NSString*)tmpAttachmentPreviewPath {
    NSString* ret = [NSTemporaryDirectory() stringByAppendingPathComponent:@"att_pr"];

    NSError* error;
    if (![[NSFileManager defaultManager] createDirectoryAtPath:ret withIntermediateDirectories:YES attributes:nil error:&error]) {
        NSLog(@"Error Creating Directory: %@ => [%@]", ret, error.localizedDescription);
    }


    
    return ret;
}

- (void)deleteAllTmpAttachmentPreviewFiles {
    NSString* tmpPath = [self tmpAttachmentPreviewPath];
    [self deleteAllFoo:tmpPath];
}

- (void)deleteAllTmpWorkingFiles { 
    [self deleteAllTmpEncryptedAttachmentWorkingFiles];
    [self deleteAllTmpSyncMergeWorkingFiles];
    [self deleteAllTmpEncryptionStreamFiles];
}

- (void)deleteAllTmpEncryptedAttachmentWorkingFiles { 
    NSString* tmpPath = [self tmpEncryptedAttachmentPath];
    [self deleteAllFoo:tmpPath];
}

- (void)deleteAllTmpSyncMergeWorkingFiles {
    NSString* tmpPath = self.syncManagerMergeWorkingDirectory.path;
    [self deleteAllFoo:tmpPath];
}

- (void)deleteAllTmpEncryptionStreamFiles {
    NSString* tmpPath = self.tmpEncryptionStreamPath;
    [self deleteAllFoo:tmpPath];
}

- (void)deleteAllFoo:(NSString*)tmpPath {
    NSArray* tmpDirectoryContents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:tmpPath error:NULL];
    
    for (NSString *file in tmpDirectoryContents) {
        NSString* path = [NSString pathWithComponents:@[tmpPath, file]];
        
        NSError* error;
        [[NSFileManager defaultManager] removeItemAtPath:path error:&error];

    }
}

- (NSArray<NSURL *> *)importedKeyFiles {
    NSMutableArray* files = [NSMutableArray array];
    NSFileManager *fm = [NSFileManager defaultManager];
    NSURL *directoryURL =  self.keyFilesDirectory;
    
    NSDirectoryEnumerator *enumerator = [fm
                                         enumeratorAtURL:directoryURL
                                         includingPropertiesForKeys:@[NSURLIsDirectoryKey]
                                         options:0
                                         errorHandler:nil];
    
    for (NSURL *url in enumerator) {
        NSError *error;
        NSNumber *isDirectory = nil;
        if (![url getResourceValue:&isDirectory forKey:NSURLIsDirectoryKey error:&error]) {
            
            NSLog(@"%@", error);
        }
        else if (![isDirectory boolValue]) {
            [files addObject:url];
        }
    }
    
    return [files copy];
}

@end
