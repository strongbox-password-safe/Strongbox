//
//  LocalDeviceStorageProvider.m
//  StrongBox
//
//  Created by Mark on 19/11/2014.
//  Copyright (c) 2014 Mark McGuill. All rights reserved.
//

#import "LocalDeviceStorageProvider.h"
#import "IOsUtils.h"
#import "Utils.h"
#import "SafesList.h"
#import "Settings.h"
#import "DatabaseModel.h"

@interface LocalDeviceStorageProvider ()

@property (nonatomic, strong) dispatch_queue_t dispatchQueue;
@property (nonatomic, strong) dispatch_source_t source;

@end

@implementation LocalDeviceStorageProvider

+ (instancetype)sharedInstance {
    static LocalDeviceStorageProvider *sharedInstance = nil;
    static dispatch_once_t onceToken;
    
    dispatch_once(&onceToken, ^{
        sharedInstance = [[LocalDeviceStorageProvider alloc] init];
    });
    return sharedInstance;
}

- (instancetype)init {
    if (self = [super init]) {
        _displayName = @"Local Device";
        _icon = @"phone";
        _storageId = kLocalDevice;
        _cloudBased = NO;
        _providesIcons = NO;
        _browsableNew = NO;
        _browsableExisting = YES;
        _rootFolderOnly = YES;
        
        NSString* appSupportDir = [self getDirectory:YES];
        
        if (![[NSFileManager defaultManager] fileExistsAtPath:appSupportDir isDirectory:NULL]) {
            NSError *error = nil;
            
            NSLog(@"Creating Application Support Directory.");
            if (![[NSFileManager defaultManager] createDirectoryAtPath:appSupportDir withIntermediateDirectories:YES attributes:nil error:&error]) {
                NSLog(@"%@", error.localizedDescription);
            }
        }

        return self;
    }
    else {
        return nil;
    }
}

- (void)    create:(NSString *)nickName
         extension:(NSString *)extension
              data:(NSData *)data
      parentFolder:(NSObject *)parentFolder
    viewController:(UIViewController *)viewController
        completion:(void (^)(SafeMetaData *metadata, NSError *error))completion {
    NSString *desiredFilename = [NSString stringWithFormat:@"%@.%@", nickName, extension];
    [self create:nickName extension:extension data:data suggestedFilename:desiredFilename completion:completion];
}

- (void)        create:(NSString *)nickName
             extension:(NSString *)extension
                  data:(NSData *)data
     suggestedFilename:(NSString*)suggestedFilename
            completion:(void (^)(SafeMetaData *metadata, NSError *error))completion {
    // Is the suggested a valid file name?
    // YES -> Does it exist
    //     Yes -> Are we allow to overwrite
    //        Yes -> Overwirte
    //        No -> Come up with new File Name and Write
    //     No -> Write
    // NO -> Come up with new File Name and Write
    
    if(![self writeWithFilename:suggestedFilename overwrite:NO data:data]) {
        suggestedFilename = [NSString stringWithFormat:@"%@.%@", nickName, extension];
        while(![self writeWithFilename:suggestedFilename overwrite:NO data:data]) {
            suggestedFilename = [Utils insertTimestampInFilename:suggestedFilename];
        }
    }
    
    NSString *path = [self getFilePathFromFileName:suggestedFilename offlineCache:NO];
    SafeMetaData *metadata = [[SafeMetaData alloc] initWithNickName:nickName storageProvider:self.storageId fileName:path.lastPathComponent fileIdentifier:path.lastPathComponent];
    metadata.offlineCacheEnabled = NO;
    completion(metadata, nil);
}

- (BOOL)writeWithFilename:(NSString*)filename overwrite:(BOOL)overwrite data:(NSData *)data {
    NSLog(@"Trying to write local file with filename [%@]", filename);
    NSString *path = [self getFilePathFromFileName:filename offlineCache:NO];

    // Does it exist?
    
    if ([[NSFileManager defaultManager] fileExistsAtPath:path]) {
        //     Yes -> Are we allow to overwrite
        if(overwrite) {
            //        Yes -> Write
            return [self write:data path:path overwrite:overwrite];
        }
        else {
            //        No -> Come up with new File Name and Write
            NSLog(@"File [%@] but not allowed to overwrite...", filename);
            return NO;
        }
    }
    else {
        // No -> Write
        return [self write:data path:path overwrite:overwrite];
    }
}

- (void)deleteAllInboxItems {
    NSFileManager *fm = [NSFileManager defaultManager];
    
    NSURL* url = [[IOsUtils applicationDocumentsDirectory] URLByAppendingPathComponent:@"Inbox"];
    
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

- (BOOL)write:(NSData*)data path:(NSString*)path overwrite:(BOOL)overwrite {
    NSError* error;
    NSUInteger flags = kNilOptions;
    if(!overwrite) {
        flags = NSDataWritingWithoutOverwriting;
    }
    
    BOOL ret = [data writeToFile:path options:flags error:&error];

    if(!ret) {
        NSLog(@"tryWrite Failed: [%@]", error);
    }
    
    return ret;
}


- (void)createOfflineCacheFile:(SafeMetaData *)safe
                          data:(NSData *)data
                    completion:(void (^)(BOOL success))completion {
    NSString *desiredFilename = [self getOfflineCacheFileName:safe];
    NSString *path = [self getFilePathFromFileName:desiredFilename offlineCache:YES];

    //NSLog(@"Creating offline cache file at: %@", path);
    
    if(![data writeToFile:path atomically:YES]) {
        NSLog(@"Error Writing offline Cache file.");
        completion(NO);
    }
    else {
        completion(YES);
    }
}

- (void)read:(SafeMetaData *)safeMetaData viewController:(UIViewController *)viewController completion:(void (^)(NSData *, NSError *error))completion {
    NSString *path = [self getFilePathFromSafeMetaData:safeMetaData offlineCache:NO];

    NSLog(@"Local Reading at: %@", path);

    NSData *data = [[NSFileManager defaultManager] contentsAtPath:path];

    completion(data, nil);
}

- (BOOL)deleteWithCaseInsensitiveFilename:(NSString *)filename {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *directory = [IOsUtils applicationDocumentsDirectory].path;
    NSError* error;
    
    for (NSString *file in [fm contentsOfDirectoryAtPath:directory error:&error]) {
        if([file caseInsensitiveCompare:filename] == NSOrderedSame) {
            NSString *path = [self getFilePathFromFileName:file offlineCache:NO];
            
            NSLog(@"Deleteing Local at: %@", path);
     
            [fm removeItemAtPath:path error:&error];
            
            if(error) {
                NSLog(@"Error Deleting: [%@]", error);
                return NO;
            }
            
            return YES;
        }
    }
    
    return NO;
}

-(NSData *)readWithCaseInsensitiveFilename:(NSString *)filename {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *directory = [IOsUtils applicationDocumentsDirectory].path;
    NSError* error;
    
    for (NSString *file in [fm contentsOfDirectoryAtPath:directory error:&error]) {
        if([file caseInsensitiveCompare:filename] == NSOrderedSame) {
            NSString *path = [self getFilePathFromFileName:file offlineCache:NO];
            
            NSLog(@"Local Reading at: %@", path);
            
            return [[NSFileManager defaultManager] contentsAtPath:path];
        }
    }
    
    return nil;
}

- (void)readOfflineCachedSafe:(SafeMetaData *)safeMetaData
               viewController:(UIViewController *)viewController
                   completion:(void (^)(NSData *, NSError *error))completion {
    NSString *path = [self getFilePathFromSafeMetaData:safeMetaData offlineCache:YES];

    NSLog(@"readOfflineCachedSafe at: %@", path);

    NSData *data = [[NSFileManager defaultManager] contentsAtPath:path];

    completion(data, nil);
}

- (void)update:(SafeMetaData *)safeMetaData
          data:(NSData *)data
    completion:(void (^)(NSError *error))completion {
    NSString *path = [self getFilePathFromSafeMetaData:safeMetaData offlineCache:NO];

    [data writeToFile:path atomically:YES ];

    completion(nil);
}

- (void)updateOfflineCachedSafe:(SafeMetaData *)safeMetaData data:(NSData *)data viewController:(UIViewController *)viewController completion:(void (^)(BOOL success))completion {
    NSString *path = [self getFilePathFromSafeMetaData:safeMetaData offlineCache:YES];

    if(![data writeToFile:path atomically:YES]) {
        NSLog(@"Error updating offline cache.");
        completion(NO);
    }
    else {
        completion(YES);
    }
}

- (void)delete:(SafeMetaData *)safeMetaData completion:(void (^)(NSError *error))completion {
    NSString *path = [self getFilePathFromSafeMetaData:safeMetaData offlineCache:NO];

    NSError *error;

    [[NSFileManager defaultManager] removeItemAtPath:path error:&error];

    if(completion != nil) {
        completion(error);
    }
}

- (void)deleteOfflineCachedSafe:(SafeMetaData *)safeMetaData completion:(void (^)(NSError *error))completion {
    NSString *path = [self getFilePathFromSafeMetaData:safeMetaData offlineCache:YES];

    NSError *error;

    [[NSFileManager defaultManager] removeItemAtPath:path error:&error];

    if(completion != nil) {
        completion(error);
    }
}

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (NSDate *)getOfflineCacheFileModificationDate:(SafeMetaData *)safeMetadata {
    NSString *path = [self getFilePathFromSafeMetaData:safeMetadata offlineCache:YES];
    
    if(![[NSFileManager defaultManager] fileExistsAtPath:path]) {
        NSLog(@"Offline cache file does NOT exist!");
        return nil;
    }
    
    NSDictionary *attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:path error:nil];

    //NSLog(@"Getting modification date for: %@ - %@", path, attributes);

    return [attributes fileModificationDate];
}

- (void)loadIcon:(NSObject *)providerData viewController:(UIViewController *)viewController
      completion:(void (^)(UIImage *image))completionHandler {
    // NOTIMPL
}

- (void)      list:(NSObject *)parentFolder
    viewController:(UIViewController *)viewController
        completion:(void (^)(BOOL, NSArray<StorageBrowserItem *> *, NSError *))completion {
    NSError* error;
    NSArray<StorageBrowserItem *> *items = [self listRoot:&error];

    completion(NO, items, error);
}

- (NSArray<StorageBrowserItem*>*)listRoot:(NSError**)ppError {
    NSError *error;
    NSArray *directoryContent = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:[self getDirectory:NO]
                                                                                    error:&error];
    
    if (error) {
        *ppError = error;
        return nil;
    }
    
    NSMutableArray<StorageBrowserItem*>* items = [NSMutableArray array];
    for (NSString* file in directoryContent)
    {
        StorageBrowserItem* browserItem = [[StorageBrowserItem alloc] init];
        
        BOOL isDirectory;
        NSString *fullPath = [self getFilePathFromFileName:file offlineCache:NO];
    
        BOOL exists = [[NSFileManager defaultManager] fileExistsAtPath:fullPath isDirectory:&isDirectory];

        if(exists) {
            browserItem.folder = isDirectory != 0;
            browserItem.name = file;
            browserItem.providerData = file;
            [items addObject:browserItem];
        }
    }
    
    return items;
}

- (void)readWithProviderData:(NSObject *)providerData
              viewController:(UIViewController *)viewController
                  completion:(void (^)(NSData *data, NSError *error))completionHandler {
    NSString *path = [self getFilePathFromFileName:(NSString *)providerData offlineCache:NO];
    
    NSLog(@"readWithProviderData at: %@", path);
    
    NSData *data = [[NSFileManager defaultManager] contentsAtPath:path];
    
    completionHandler(data, nil);
}

- (SafeMetaData *)getSafeMetaData:(NSString *)nickName providerData:(NSObject *)providerData {
    return [[SafeMetaData alloc] initWithNickName:nickName
                                  storageProvider:self.storageId
                                         fileName:(NSString*)providerData
                                   fileIdentifier:(NSString*)providerData];
}

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)createAutoFillCache:(SafeMetaData *)safeMetaData data:(NSData *)data completion:(void (^)(BOOL success))completion {
    NSString *filePath = getAutoFillFilePath(safeMetaData);
    NSLog(@"Creating AutoFill cache file at: %@", filePath);
    
    NSError* error;
    if(![data writeToFile:filePath options:NSDataWritingAtomic error:&error]) {
        NSLog(@"Error Writing AutoFill Cache file. [%@]", error);
        completion(NO);
    }
    else {
        completion(YES);
    }
}

- (void)readAutoFillCache:(SafeMetaData *)safeMetaData viewController:(UIViewController *)viewController completion:(void (^)(NSData *, NSError *error))completion {
    NSString *filePath = getAutoFillFilePath(safeMetaData);
    
    NSLog(@"Reading AutoFill cache file at: %@", filePath);
    
    NSError* error;
    NSData *data = [NSData dataWithContentsOfFile:filePath options:kNilOptions error:&error];
    
    if(!data) {
        NSLog(@"Error Reading AutoFill Cache File: [%@]", error);
    }
    
    completion(data, error);
}

- (void)updateAutoFillCache:(SafeMetaData *)safeMetaData data:(NSData *)data viewController:(UIViewController *)viewController completion:(void (^)(BOOL success))completion {
    NSString *filePath = getAutoFillFilePath(safeMetaData);
    
    //NSLog(@"Updating AutoFill cache file at: %@", filePath);
    
    NSError* error;
    if(![data writeToFile:filePath options:NSDataWritingAtomic error:&error]) {
        NSLog(@"Error updating AutoFill cache. [%@]", error);
        completion(NO);
    }
    else {
        completion(YES);
    }
}

- (void)deleteAutoFillCache:(SafeMetaData *)safeMetaData completion:(void (^)(NSError *error))completion {
    NSString *filePath = getAutoFillFilePath(safeMetaData);
    NSError *error;
    
    NSLog(@"Deleting AutoFill cache file at: %@", filePath);
    
    [[NSFileManager defaultManager] removeItemAtPath:filePath error:&error];

    if(completion != nil) {
        completion(error);
    }
}

- (NSDate *)getAutoFillCacheModificationDate:(SafeMetaData *)safeMetadata {
    NSString *filePath = getAutoFillFilePath(safeMetadata);
    
    if(![[NSFileManager defaultManager] fileExistsAtPath:filePath]) {
        NSLog(@"Offline cache file does NOT exist!");
        return nil;
    }
    
    NSDictionary *attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:filePath error:nil];
    
    //NSLog(@"Getting modification date for: %@ - %@", filePath, attributes);
    
    return [attributes fileModificationDate];
}

static NSString* getAutoFillCacheFileName(SafeMetaData* safe) {
    return [NSString stringWithFormat:@"%@-autofill-cache.dat", safe.uuid];
}

static NSString* getAutoFillCacheDirectory() {
    NSURL* url = [[NSFileManager defaultManager] containerURLForSecurityApplicationGroupIdentifier:kAppGroupName];
    NSString* ret = [url.path stringByAppendingPathComponent:@"auto-fill-caches"];
    NSError* error;
    
    //NSLog(@"Creating Auto Fill Cache Directory.");
    if (![[NSFileManager defaultManager] createDirectoryAtPath:ret withIntermediateDirectories:YES attributes:nil error:&error]) {
        NSLog(@"Error Auto Fill Cache Directory: %@", error.localizedDescription);
    }
    
    return ret;
}

static NSString* getAutoFillFilePath(SafeMetaData* safeMetaData) {
    NSString* autoFillCacheDir = getAutoFillCacheDirectory();
    return [autoFillCacheDir stringByAppendingPathComponent:getAutoFillCacheFileName(safeMetaData)];
}
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)startMonitoringDocumentsDirectory:(void (^)(void))completion
{
    #define fileChangedNotification @"fileChangedNotification"
    
    // Get the path to the home directory
    NSString * homeDirectory = [self getDirectory:NO];
    
    // Create a new file descriptor - we need to convert the NSString to a char * i.e. C style string
    int filedes = open([homeDirectory cStringUsingEncoding:NSASCIIStringEncoding], O_EVTONLY);
    
    // Create a dispatch queue - when a file changes the event will be sent to this queue
    _dispatchQueue = dispatch_queue_create("FileMonitorQueue", 0);
    
    // Create a GCD source. This will monitor the file descriptor to see if a write command is detected
    // The following options are available
    
    // Write covers - adding a file, renaming a file and deleting a file...
    _source = dispatch_source_create(DISPATCH_SOURCE_TYPE_VNODE,filedes,
                                     DISPATCH_VNODE_WRITE,
                                     _dispatchQueue);
    
    // This block will be called when teh file changes
    dispatch_source_set_event_handler(_source, ^(){
        // We call an NSNotification so the file can change can be detected anywhere
        [[NSNotificationCenter defaultCenter] postNotificationName:fileChangedNotification object:Nil];
    });
    
    // When we stop monitoring the file this will be called and it will close the file descriptor
    dispatch_source_set_cancel_handler(_source, ^() {
        close(filedes);
    });
    
    // Start monitoring the file...
    dispatch_resume(_source);
    
    // To recieve a notification about the file change we can use the NSNotificationCenter
    [[NSNotificationCenter defaultCenter] addObserverForName:fileChangedNotification object:Nil queue:Nil usingBlock:^(NSNotification * notification) {
        dispatch_async(dispatch_get_main_queue(), ^(void) {
            completion();
        });
    }];
}

- (void)stopMonitoringDocumentsDirectory
{
    dispatch_source_cancel(_source);
}

- (NSArray<StorageBrowserItem *>*)scanForNewSafes {
    NSArray<SafeMetaData*> * localSafes = [SafesList.sharedInstance getSafesOfProvider:kLocalDevice];
    NSMutableSet *existing = [NSMutableSet set];
    for (SafeMetaData* safe in localSafes) {
        [existing addObject:safe.fileName];
    }
    
    NSError* error;
    NSArray<StorageBrowserItem *> *items = [self listRoot:&error];
    NSMutableArray<StorageBrowserItem *> *newSafes = [NSMutableArray array];

    if(items) {
        for (StorageBrowserItem *item in items) {
            if(!item.folder && ![existing containsObject:item.name]) {
                NSString *path = [self getFilePathFromFileName:item.name offlineCache:NO];
                
                NSData *data = [[NSFileManager defaultManager] contentsAtPath:path];
                
                if([DatabaseModel isAValidSafe:data error:&error]) {
                    NSLog(@"New File:%@ is a valid safe", item.name);
                    [newSafes addObject:item];
                }
                else {
                    //NSLog(@"None Safe File:%@ is a not valid safe", item.name);
                }
            }
        }
    }
    else {
        NSLog(@"Error Scanning for New Files. List Root: %@", error);
    }
    
    return newSafes;
}

- (BOOL)fileExists:(SafeMetaData*)metaData {
    NSString *fullPath = [self getFilePathFromSafeMetaData:metaData offlineCache:NO];
    return [[NSFileManager defaultManager] fileExistsAtPath:fullPath];
}

- (BOOL)fileNameExists:(NSString*)filename {
    NSString *fullPath = [self getFilePathFromFileName:filename offlineCache:NO];
    
    return [[NSFileManager defaultManager] fileExistsAtPath:fullPath];
}


////////////////////////////////////////////////////////////////////////////////////////////////////////
//

- (NSString*)getOfflineCacheFileName:(SafeMetaData*)safe {
    return [NSString stringWithFormat:@"%@-offline-cache.dat", safe.uuid];
}

- (NSURL*)getFileUrl:(SafeMetaData*)safeMetaData {
    NSString *path = [self getFilePathFromSafeMetaData:safeMetaData offlineCache:NO];
    return [NSURL fileURLWithPath:path];
}

- (NSString *)getFilePathFromSafeMetaData:(SafeMetaData *)safeMetaData offlineCache:(BOOL)offlineCache {
    if(offlineCache) {
        NSString *filename = [self getOfflineCacheFileName:safeMetaData];
        
        return [self getFilePathFromFileName:filename offlineCache:YES];
    }
    else {
        return [self getFilePathFromFileName:safeMetaData.fileIdentifier.lastPathComponent offlineCache:NO];
    }
}

- (NSString*)getFilePathFromFileName:(NSString*)fileName offlineCache:(BOOL)offlineCache {
    return [[self getDirectory:offlineCache] stringByAppendingPathComponent:fileName];
}

- (NSString*)getDirectory:(BOOL)offlineCache {
    if(offlineCache) {
        return [IOsUtils applicationSupportDirectory].path;
    }
    else {
        // FUTURE: Maybe we could make Local Safes eligible for auto fill by offering user a choice.
        // Basically if we move to the Group Container iTunes File Sharing/Files app no longer works. So it's either/or
        // Seems like Apple didn't really think this one through fully
        //
        //NSString *appGroupDirectoryPath = [[NSFileManager defaultManager] containerURLForSecurityApplicationGroupIdentifier:kAppGroupName].path;
        //return Settings.sharedInstance.makeLocalSafesAvailableForAutoFill ? appGroupDirectoryPath : [IOsUtils applicationDocumentsDirectory].path;
        
        return [IOsUtils applicationDocumentsDirectory].path;
    }
}

- (void)excludeDirectoriesFromBackup {
    NSString* path = [IOsUtils applicationDocumentsDirectory].path;
    [self excludeFromBackup:path];
    
    path = [IOsUtils applicationSupportDirectory].path;
    [self excludeFromBackup:path];
    
//    NSArray *directoryContent = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:path error:NULL];
//
//    for (int count = 0; count < (int)[directoryContent count]; count++)
//    {
//        NSLog(@"File %d: %@", (count + 1), [directoryContent objectAtIndex:count]);
//
//        NSString *file = [path stringByAppendingPathComponent:[directoryContent objectAtIndex:count]];
//
//        [self excludeFromBackup:file];
//    }
}

- (void)excludeFromBackup:(NSString*)path {
    NSError *error = nil;
    
    NSURL* URL = [NSURL fileURLWithPath:path];
    
    BOOL success = [URL setResourceValue:[NSNumber numberWithBool:YES]
                                  forKey:NSURLIsExcludedFromBackupKey
                                   error:&error];
    if(!success){
        NSLog(@"Error excluding %@ from backup %@", [URL lastPathComponent], error);
    }
}

//

- (void)deleteAllLocalAndAppGroupFiles {
    [self deleteAllInDirectory:[IOsUtils applicationDocumentsDirectory]];

    [self deleteAllInDirectory:[IOsUtils applicationSupportDirectory]];

    NSURL* url = [[NSFileManager defaultManager] containerURLForSecurityApplicationGroupIdentifier:kAppGroupName];
    
    [self deleteAllInDirectory:url];
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

@end
