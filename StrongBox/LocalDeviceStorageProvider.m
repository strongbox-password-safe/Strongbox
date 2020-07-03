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
        completion:(void (^)(BOOL, NSArray<StorageBrowserItem *> *, const NSError *))completion {
    // NOTIMPL
}

- (void)readWithProviderData:(NSObject *)providerData
              viewController:(UIViewController *)viewController
                  completion:(void (^)(NSData *data, const NSError *error))completionHandler {
    // NOTIMPL
}

- (SafeMetaData *)getSafeMetaData:(NSString *)nickName providerData:(NSObject *)providerData {
    LocalDatabaseIdentifier* identifier = (LocalDatabaseIdentifier*)providerData;
    
    return [[SafeMetaData alloc] initWithNickName:nickName
                                  storageProvider:self.storageId
                                         fileName:identifier.filename
                                   fileIdentifier:[identifier toJson]];
}

- (void)read:(nonnull SafeMetaData *)safeMetaData viewController:(UIViewController *)viewController completion:(nonnull void (^)(NSData * _Nullable, const NSError * _Nullable))completion {
    [self readNonInteractive:safeMetaData completion:completion];
}

- (void)readLegacy:(nonnull SafeMetaData *)safeMetaData viewController:(nonnull UIViewController *)viewController isAutoFill:(BOOL)isAutoFill completion:(nonnull void (^)(NSData * _Nullable, const NSError * _Nullable))completion {
    [self readNonInteractive:safeMetaData completion:completion];
}

- (void)readNonInteractive:(nonnull SafeMetaData *)safeMetaData completion:(nonnull void (^)(NSData * _Nullable, const NSError * _Nullable))completion {
    NSURL *url = [self getFileUrl:safeMetaData];

    NSLog(@"Local Reading at: %@", url);

    NSData *data = [[NSFileManager defaultManager] contentsAtPath:url.path];

    completion(data, nil);
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

@end
