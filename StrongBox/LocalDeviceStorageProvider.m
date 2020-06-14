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
#import "FileManager.h"
#import "LocalDatabaseIdentifier.h"

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
        _displayName = NSLocalizedString(@"storage_provider_name_local_device", @"Local Device");
        if([self.displayName isEqualToString:@"storage_provider_name_local_device"]) {
            _displayName = @"Local Device";
        }
        
        _icon = @"iphone_x";
        _storageId = kLocalDevice;
        _allowOfflineCache = NO;
        _providesIcons = NO;
        _browsableNew = NO;
        _browsableExisting = YES;
        _rootFolderOnly = YES;
        _immediatelyOfferCacheIfOffline = NO;
        
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
    
    if(![self writeToDefaultStorageWithFilename:suggestedFilename overwrite:NO data:data]) {
        suggestedFilename = [NSString stringWithFormat:@"%@.%@", nickName, extension];
        while(![self writeToDefaultStorageWithFilename:suggestedFilename overwrite:NO data:data]) {
            suggestedFilename = [Utils insertTimestampInFilename:suggestedFilename];
        }
    }
    
    LocalDatabaseIdentifier *identifier = [[LocalDatabaseIdentifier alloc] init];
    identifier.filename = suggestedFilename;
    identifier.sharedStorage = YES;
    
    SafeMetaData *metadata = [self getSafeMetaData:nickName providerData:identifier];
    completion(metadata, nil);
}

- (BOOL)writeToDefaultStorageWithFilename:(NSString*)filename overwrite:(BOOL)overwrite data:(NSData *)data {
    NSLog(@"Trying to write local file with filename [%@]", filename);
    NSString *path = [self getDefaultStorageFileUrl:filename].path;

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

- (void)read:(SafeMetaData *)safeMetaData viewController:(UIViewController *)viewController isAutoFill:(BOOL)isAutoFill completion:(void (^)(NSData * _Nullable, NSError * _Nullable))completion {
    NSURL *url = [self getFileUrl:safeMetaData];

    NSLog(@"Local Reading at: %@", url);

    NSData *data = [[NSFileManager defaultManager] contentsAtPath:url.path];

    completion(data, nil);
}

- (void)update:(SafeMetaData *)safeMetaData data:(NSData *)data isAutoFill:(BOOL)isAutoFill completion:(void (^)(NSError * _Nullable))completion {
    NSURL* url = [self getFileUrl:safeMetaData];

    [data writeToFile:url.path atomically:YES];

    completion(nil);
}


- (void)delete:(SafeMetaData *)safeMetaData completion:(void (^)(NSError *error))completion {
    NSURL *url = [self getFileUrl:safeMetaData];

    NSError *error;

    [[NSFileManager defaultManager] removeItemAtPath:url.path error:&error];

    if(completion != nil) {
        completion(error);
    }
}

- (void)loadIcon:(NSObject *)providerData viewController:(UIViewController *)viewController
      completion:(void (^)(UIImage *image))completionHandler {
    // NOTIMPL
}

- (void)      list:(NSObject *)parentFolder
    viewController:(UIViewController *)viewController
        completion:(void (^)(BOOL, NSArray<StorageBrowserItem *> *, NSError *))completion {
    // NOTIMPL
}

- (void)readWithProviderData:(NSObject *)providerData
              viewController:(UIViewController *)viewController
                  completion:(void (^)(NSData *data, NSError *error))completionHandler {
    // NOTIMPL
}

- (SafeMetaData *)getSafeMetaData:(NSString *)nickName providerData:(NSObject *)providerData {
    LocalDatabaseIdentifier* identifier = (LocalDatabaseIdentifier*)providerData;
    
    return [[SafeMetaData alloc] initWithNickName:nickName
                                  storageProvider:self.storageId
                                         fileName:identifier.filename
                                   fileIdentifier:[identifier toJson]];
}

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)startMonitoringDocumentsDirectory {
#define fileChangedNotification @"fileChangedNotification"
    
    // Get the path to the home directory
    NSString * homeDirectory = FileManager.sharedInstance.documentsDirectory.path;
    
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
            NSLog(@"File Change Detected! Scanning for New Safes");
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
                [self syncLocalSafesWithFileSystem];
            });
        });
    }];
    
    [self syncLocalSafesWithFileSystem];
}

- (void)stopMonitoringDocumentsDirectory {
    dispatch_source_cancel(_source);
}

- (NSArray<StorageBrowserItem *>*)scanForNewDatabases {
    NSArray<SafeMetaData*> * localSafes = [SafesList.sharedInstance getSafesOfProvider:kLocalDevice];
    NSMutableSet *existing = [NSMutableSet set];
    for (SafeMetaData* safe in localSafes) {
        LocalDatabaseIdentifier* identifier = [self getIdentifierFromMetadata:safe];
        if(identifier && !identifier.sharedStorage) {
            [existing addObject:identifier.filename];
        }
    }
    
    NSError* error;
    NSArray<StorageBrowserItem *> *items = [self getDocumentFiles:&error];
    NSMutableArray<StorageBrowserItem *> *newSafes = [NSMutableArray array];
    
    if(items) {
        for (StorageBrowserItem *item in items) {
            if(!item.folder && ![existing containsObject:item.name]) {
                NSString *path = [self getFileUrl:NO filename:item.name].path;
                
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

- (NSArray<StorageBrowserItem*>*)getDocumentFiles:(NSError**)ppError {
    NSError *error;
    NSArray *directoryContent = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:FileManager.sharedInstance.documentsDirectory.path
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
        NSString *fullPath = [self getFileUrl:NO filename:file].path;
        
        BOOL exists = [[NSFileManager defaultManager] fileExistsAtPath:fullPath isDirectory:&isDirectory];
        
        if(exists) {
            browserItem.folder = isDirectory != 0;
            browserItem.name = file;
            
            LocalDatabaseIdentifier *identifier = [[LocalDatabaseIdentifier alloc] init];
            identifier.sharedStorage = NO;
            identifier.filename = file;
            
            browserItem.providerData = identifier;
            
            [items addObject:browserItem];
        }
    }
    
    return items;
}

- (void)syncLocalSafesWithFileSystem {
    // Add any new

#ifndef IS_APP_EXTENSION // TODO: Part of effort to make Auto-Fill Component Read Only - Remove on move to new SyncManager

    NSArray<StorageBrowserItem*> *items = [self scanForNewDatabases];
    
    if(items.count) {
        for(StorageBrowserItem* item in items) {
            NSString* name = [SafesList sanitizeSafeNickName:[item.name stringByDeletingPathExtension]];
            SafeMetaData *safe = [LocalDeviceStorageProvider.sharedInstance getSafeMetaData:name
                                                                               providerData:item.providerData];
            [[SafesList sharedInstance] addWithDuplicateCheck:safe];
        }
    }
    
    // Remove deleted
    
    NSArray<SafeMetaData*> *localSafes = [SafesList.sharedInstance getSafesOfProvider:kLocalDevice];
    
    for (SafeMetaData* localSafe in localSafes) {
        if(![self fileExists:localSafe]) {
            NSLog(@"Removing Safe [%@] because underlying file [%@] no longer exists in Documents Directory.", localSafe.nickName, localSafe.fileName);
            [SafesList.sharedInstance remove:localSafe.uuid];
        }
    }
    
#endif

}

////////////////////////////////////////////////////////////////////////////////////////////////////////

- (LocalDatabaseIdentifier*)getIdentifierFromMetadata:(SafeMetaData*)metaData {
    NSString* json = metaData.fileIdentifier;
    return [LocalDatabaseIdentifier fromJson:json];
}

- (NSURL*)getDirectory:(BOOL)shared {
    return shared ? FileManager.sharedInstance.sharedAppGroupDirectory : FileManager.sharedInstance.documentsDirectory;
}

- (NSURL*)getFileUrl:(SafeMetaData*)safeMetaData {
    LocalDatabaseIdentifier* identifier = [self getIdentifierFromMetadata:safeMetaData];
    return identifier ? [self getFileUrl:identifier.sharedStorage filename:identifier.filename] : nil;
}

- (NSURL*)getFileUrl:(BOOL)sharedStorage filename:(NSString*)filename {
    NSURL* folder = [self getDirectory:sharedStorage];
    return [folder URLByAppendingPathComponent:filename];
}

- (BOOL)fileExists:(SafeMetaData*)metaData {
    NSURL *fullPath = [self getFileUrl:metaData];
    return [[NSFileManager defaultManager] fileExistsAtPath:fullPath.path];
}

- (NSURL*)getDefaultStorageFileUrl:(NSString*)filename {
    NSURL* folder = [self getDirectory:YES];
    return [folder URLByAppendingPathComponent:filename];
}

- (BOOL)fileNameExistsInDefaultStorage:(NSString*)filename {
    NSURL *fullPath = [self getDefaultStorageFileUrl:filename];
    return [[NSFileManager defaultManager] fileExistsAtPath:fullPath.path];
}

- (BOOL)isUsingSharedStorage:(SafeMetaData*)metadata {
    LocalDatabaseIdentifier* identifier = [self getIdentifierFromMetadata:metadata];
    return identifier.sharedStorage;
}

- (BOOL)toggleSharedStorage:(SafeMetaData*)metadata error:(NSError**)error {
    LocalDatabaseIdentifier* identifier = [self getIdentifierFromMetadata:metadata];

    NSURL* src = [self getFileUrl:identifier.sharedStorage filename:identifier.filename];
    NSURL* dest = [self getFileUrl:!identifier.sharedStorage filename:identifier.filename];

    int i=0;
    NSString* extension = [identifier.filename pathExtension];
    NSString* baseFileName = [identifier.filename stringByDeletingPathExtension];
    
    // Avoid Race Conditions
    
    [self stopMonitoringDocumentsDirectory];
    
    while ([[NSFileManager defaultManager] fileExistsAtPath:dest.path]) {
        identifier.filename = [[baseFileName stringByAppendingFormat:@"-%d", i] stringByAppendingPathExtension:extension];
        
        dest = [self getFileUrl:!identifier.sharedStorage filename:identifier.filename];
        
        NSLog(@"File exists at destination... Trying: [%@]", dest);
    }
    
    if(![NSFileManager.defaultManager moveItemAtURL:src toURL:dest error:error]) {
        NSLog(@"Error moving local file: [%@]", *error);
        [self startMonitoringDocumentsDirectory];
        return NO;
    }
    else {
        NSLog(@"OK - Moved local file: [%@] -> [%@]", src, dest);
    }
    
    identifier.sharedStorage = !identifier.sharedStorage;
    
    metadata.fileIdentifier = [identifier toJson];
    metadata.fileName = identifier.filename;

#ifndef IS_APP_EXTENSION // TODO: Part of effort to make Auto-Fill Component Read Only - Remove on move to new SyncManager
    [SafesList.sharedInstance update:metadata];
#endif
    
    [self startMonitoringDocumentsDirectory];
    
    return YES;
}

@end
