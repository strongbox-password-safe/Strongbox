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
        
        return self;
    }
    else {
        return nil;
    }
}

- (void)    create:(NSString *)nickName
              data:(NSData *)data
      parentFolder:(NSObject *)parentFolder
    viewController:(UIViewController *)viewController
        completion:(void (^)(SafeMetaData *metadata, NSError *error))completion {
    NSString *desiredFilename = [NSString stringWithFormat:@"%@-strongbox.dat", nickName];

    NSString *path = [[IOsUtils applicationDocumentsDirectory].path
                      stringByAppendingPathComponent:desiredFilename];

    if ([[NSFileManager defaultManager] fileExistsAtPath:path]) {
        path = [Utils insertTimestampInFilename:path];
    }

    [data writeToFile:path atomically:YES];

    SafeMetaData *metadata = [[SafeMetaData alloc] initWithNickName:nickName storageProvider:self.storageId fileName:path.lastPathComponent fileIdentifier:path.lastPathComponent];

    metadata.offlineCacheEnabled = NO;

    completion(metadata, nil);
}

- (NSString*)getOfflineCacheFileName:(SafeMetaData*)safe {
    return [NSString stringWithFormat:@"%@-offline-cache.dat", safe.uuid];
}

- (void)createOfflineCacheFile:(SafeMetaData *)safe
                          data:(NSData *)data
                    completion:(void (^)(BOOL success))completion {
    NSString* appSupportDir = [IOsUtils applicationSupportDirectory].path;

    if (![[NSFileManager defaultManager] fileExistsAtPath:appSupportDir isDirectory:NULL]) {
        NSError *error = nil;
        
        NSLog(@"Creating Application Support Directory.");
        if (![[NSFileManager defaultManager] createDirectoryAtPath:appSupportDir withIntermediateDirectories:YES attributes:nil error:&error]) {
            NSLog(@"%@", error.localizedDescription);
        }
    }
    
    NSString *desiredFilename = [self getOfflineCacheFileName:safe];
    NSString *path = [appSupportDir stringByAppendingPathComponent:desiredFilename];
    
    NSLog(@"Creating offline cache file at: %@", path);
    
    if(![data writeToFile:path atomically:YES]) {
        NSLog(@"Error Writing offline Cache file.");
        completion(NO);
    }
    else {
        completion(YES);
    }
}

- (void)read:(SafeMetaData *)safeMetaData viewController:(UIViewController *)viewController completion:(void (^)(NSData *, NSError *error))completion {
    NSString *path = [self getFilePath:safeMetaData offlineCache:NO];

    NSLog(@"Local Reading at: %@", path);

    NSData *data = [[NSFileManager defaultManager] contentsAtPath:path];

    completion(data, nil);
}

- (void)readOfflineCachedSafe:(SafeMetaData *)safeMetaData
               viewController:(UIViewController *)viewController
                   completion:(void (^)(NSData *, NSError *error))completion {
    NSString *path = [self getFilePath:safeMetaData offlineCache:YES];

    NSLog(@"readOfflineCachedSafe at: %@", path);

    NSData *data = [[NSFileManager defaultManager] contentsAtPath:path];

    completion(data, nil);
}

- (void)update:(SafeMetaData *)safeMetaData
          data:(NSData *)data
    completion:(void (^)(NSError *error))completion {
    NSString *path = [self getFilePath:safeMetaData offlineCache:NO];

    [data writeToFile:path atomically:YES ];

    completion(nil);
}

- (void)updateOfflineCachedSafe:(SafeMetaData *)safeMetaData data:(NSData *)data viewController:(UIViewController *)viewController completion:(void (^)(BOOL success))completion {
    NSLog(@"updateOfflineCachedSafe");
    
    NSString *path = [self getFilePath:safeMetaData offlineCache:YES];

    if(![data writeToFile:path atomically:YES]) {
        NSLog(@"Error updating offline cache.");
        completion(NO);
    }
    else {
        completion(YES);
    }
}

- (void)delete:(SafeMetaData *)safeMetaData completion:(void (^)(NSError *error))completion {
    NSString *path = [self getFilePath:safeMetaData offlineCache:NO];

    NSError *error;

    [[NSFileManager defaultManager] removeItemAtPath:path error:&error];

    completion(error);
}

- (void)deleteOfflineCachedSafe:(SafeMetaData *)safeMetaData completion:(void (^)(NSError *error))completion {
    NSString *path = [self getFilePath:safeMetaData offlineCache:YES];

    NSError *error;

    [[NSFileManager defaultManager] removeItemAtPath:path error:&error];

    completion(error);
}

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (NSURL*)getFileUrl:(SafeMetaData*)safeMetaData {
    NSString *path = [self getFilePath:safeMetaData offlineCache:NO];
    return [NSURL fileURLWithPath:path];
}

- (NSString *)getFilePath:(SafeMetaData *)safeMetaData offlineCache:(BOOL)offlineCache {
    if(offlineCache) {
        NSString *filename = [self getOfflineCacheFileName:safeMetaData];

        NSString *path = [[IOsUtils applicationSupportDirectory].path
                          stringByAppendingPathComponent:filename];
        
        return path;
    }
    else {
        NSString *path = [[IOsUtils applicationDocumentsDirectory].path
                          stringByAppendingPathComponent:
                          safeMetaData.fileIdentifier.lastPathComponent];
        
        return path;
    }
}

- (NSDate *)getOfflineCacheFileModificationDate:(SafeMetaData *)safeMetadata {
    NSString *path = [self getFilePath:safeMetadata offlineCache:YES];
    
    if(![[NSFileManager defaultManager] fileExistsAtPath:path]) {
        NSLog(@"Offline cache file does NOT exist!");
        return nil;
    }
    
    NSDictionary *attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:path error:nil];

    NSLog(@"Getting modification date for: %@ - %@", path, attributes);

    return [attributes fileModificationDate];
}

- (void)loadIcon:(NSObject *)providerData viewController:(UIViewController *)viewController
      completion:(void (^)(UIImage *image))completionHandler {
    // NOTIMPL
}

- (void)      list:(NSObject *)parentFolder
    viewController:(UIViewController *)viewController
        completion:(void (^)(NSArray<StorageBrowserItem *> *items, NSError *error))completion {
    NSError* error;
    NSArray<StorageBrowserItem *> *items = [self listRoot:&error];

    completion(items, error);
}

- (NSArray<StorageBrowserItem*>*)listRoot:(NSError**)ppError {
    NSError *error;
    NSArray *directoryContent = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:[IOsUtils applicationDocumentsDirectory].path
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
        NSString *fullPath = [NSString pathWithComponents:@[[IOsUtils applicationDocumentsDirectory].path, file]];
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
    NSString *path = [[IOsUtils applicationDocumentsDirectory].path
                      stringByAppendingPathComponent:
                      (NSString*)providerData];
    
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

- (void)startMonitoringDocumentsDirectory:(void (^)(void))completion
{
    #define fileChangedNotification @"fileChangedNotification"
    
    // Get the path to the home directory
    NSString * homeDirectory = [IOsUtils applicationDocumentsDirectory].path; //NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES)[0];
    
    // Create a new file descriptor - we need to convert the NSString to a char * i.e. C style string
    int filedes = open([homeDirectory cStringUsingEncoding:NSASCIIStringEncoding], O_EVTONLY);
    
    // Create a dispatch queue - when a file changes the event will be sent to this queue
    _dispatchQueue = dispatch_queue_create("FileMonitorQueue", 0);
    
    // Create a GCD source. This will monitor the file descriptor to see if a write command is detected
    // The following options are available
    
    /*!
     * @typedef dispatch_source_vnode_flags_t
     * Type of dispatch_source_vnode flags
     *
     * @constant DISPATCH_VNODE_DELETE
     * The filesystem object was deleted from the namespace.
     *
     * @constant DISPATCH_VNODE_WRITE
     * The filesystem object data changed.
     *
     * @constant DISPATCH_VNODE_EXTEND
     * The filesystem object changed in size.
     *
     * @constant DISPATCH_VNODE_ATTRIB
     * The filesystem object metadata changed.
     *
     * @constant DISPATCH_VNODE_LINK
     * The filesystem object link count changed.
     *
     * @constant DISPATCH_VNODE_RENAME
     * The filesystem object was renamed in the namespace.
     *
     * @constant DISPATCH_VNODE_REVOKE
     * The filesystem object was revoked.
     */
    
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
                NSString *path = [[IOsUtils applicationDocumentsDirectory].path
                                  stringByAppendingPathComponent:item.name];
                
                NSData *data = [[NSFileManager defaultManager] contentsAtPath:path];
                
                if([DatabaseModel isAValidSafe:data]) {
                    NSLog(@"New File:%@ is a valid safe", item.name);
                    [newSafes addObject:item];
                }
                else {
                    NSLog(@"None Safe File:%@ is a not valid safe", item.name);
                }
            }
        }
    }
    else {
        NSLog(@"Error Scanning for New Files. List Root: %@", error);
    }
    
    return newSafes;
}

@end
