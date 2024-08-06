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
#import "DatabasePreferences.h"
#import "DatabaseModel.h"
#import "StrongboxiOSFilesManager.h"
#import "LocalDatabaseIdentifier.h"
#import "NSDate+Extensions.h"

#ifndef IS_APP_EXTENSION
#import "Strongbox-Swift.h"
#else
#import "Strongbox_Auto_Fill-Swift.h"
#endif

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
        _storageId = kLocalDevice;
        _providesIcons = NO;
        _browsableNew = NO;
        _browsableExisting = YES;
        _rootFolderOnly = YES;
        _defaultForImmediatelyOfferOfflineCache = NO;
        _supportsConcurrentRequests = NO;
        
        return self;
    }
    else {
        return nil;
    }
}

- (void)create:(NSString *)nickName
      fileName:(NSString *)fileName
          data:(NSData *)data
  parentFolder:(NSObject *)parentFolder
viewController:(VIEW_CONTROLLER_PTR)viewController
    completion:(void (^)(METADATA_PTR _Nullable, const NSError * _Nullable))completion {
    [self create:nickName fileName:fileName data:data modDate:NSDate.date completion:completion];
}

- (void)create:(NSString *)nickName
      fileName:(NSString *)fileName
          data:(NSData *)data
       modDate:(NSDate*)modDate
    completion:(void (^)(METADATA_PTR _Nullable, const NSError * _Nullable))completion {
    if(![self writeToDefaultStorageWithFilename:fileName overwrite:NO data:data modDate:modDate]) {
        fileName = [Utils insertTimestampInFilename:fileName];
        
        while(![self writeToDefaultStorageWithFilename:fileName overwrite:NO data:data modDate:modDate]) {
            fileName = [Utils insertTimestampInFilename:fileName];
        }
    }
    
    LocalDatabaseIdentifier *identifier = [[LocalDatabaseIdentifier alloc] init];
    identifier.filename = fileName;
    identifier.sharedStorage = YES;
    
    DatabasePreferences *metadata = [self getDatabasePreferences:nickName providerData:identifier];
    
    completion(metadata, nil);
}

- (BOOL)writeToDefaultStorageWithFilename:(NSString*)filename overwrite:(BOOL)overwrite data:(NSData *)data modDate:(NSDate*_Nullable)modDate {
    slog(@"Trying to write local file with filename [%@]", filename);
    NSString *path = [self getDefaultStorageFileUrl:filename].path;
    
    return [self writeToPath:path overwrite:overwrite data:data modDate:modDate];
}

- (BOOL)writeToDocumentsWithFilename:(NSString *)filename overwrite:(BOOL)overwrite data:(NSData *)data modDate:(NSDate *)modDate {
    slog(@"Trying to write local file with filename [%@]", filename);
    NSString *path = [self getDocumentsFileUrl:filename].path;
    
    return [self writeToPath:path overwrite:overwrite data:data modDate:modDate];
}

- (BOOL)writeToPath:(NSString*)path overwrite:(BOOL)overwrite data:(NSData *)data modDate:(NSDate*_Nullable)modDate {
    
    
    BOOL ret;
    if ([[NSFileManager defaultManager] fileExistsAtPath:path]) {
        
        if(overwrite) {
            
            ret = [self write:data path:path overwrite:overwrite];
        }
        else {
            
            slog(@"File [%@] but not allowed to overwrite...", path);
            ret = NO;
        }
    }
    else {
        
        ret = [self write:data path:path overwrite:overwrite];
    }
    
    if ( !ret ) {
        return NO;
    }
    else {
        if ( modDate ) {
            NSError* err2;
            [NSFileManager.defaultManager setAttributes:@{ NSFileModificationDate : modDate }
                                           ofItemAtPath:path
                                                  error:&err2];
            if ( err2 ) {
                slog(@"WARNWARN: writeToDefaultStorageWithFilename -> could not set mod date: [%@]", err2);
            }
        }
        
        return YES;
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
        slog(@"tryWrite Failed: [%@]", error);
    }
    
    return ret;
}

- (void)pushDatabase:(DatabasePreferences *)safeMetaData interactiveVC:(UIViewController *)viewController data:(NSData *)data completion:(StorageProviderUpdateCompletionBlock)completion {
    NSURL* url = [self getFileUrl:safeMetaData];
    
    NSError* error;
    BOOL success = [data writeToFile:url.path options:NSDataWritingAtomic error:&error];
    if (success) {
        NSDictionary* attr = [NSFileManager.defaultManager attributesOfItemAtPath:url.path error:&error];
        if (error) {
            completion(kUpdateResultError, nil, error);
        }
        else {
            completion(kUpdateResultSuccess, attr.fileModificationDate, nil);
        }
    }
    else {
        completion(kUpdateResultError, nil, error);
    }
}

- (void)delete:(DatabasePreferences *)safeMetaData completion:(void (^)(NSError *error))completion {
    NSURL *url = [self getFileUrl:safeMetaData];
    
    if ( [NSFileManager.defaultManager fileExistsAtPath:url.path] ) {
        NSError *error;
        
        [[NSFileManager defaultManager] removeItemAtPath:url.path error:&error];
        
        if(completion != nil) {
            completion(error);
        }
    }
    else {
        if(completion != nil) {
            completion(nil);
        }
    }
}

- (void)loadIcon:(NSObject *)providerData viewController:(UIViewController *)viewController
      completion:(void (^)(UIImage *image))completionHandler {
    
}

- (void)      list:(NSObject *)parentFolder
    viewController:(UIViewController *)viewController
        completion:(void (^)(BOOL, NSArray<StorageBrowserItem *> *, const NSError *))completion {
    
}

- (void)readWithProviderData:(NSObject *)providerData viewController:(UIViewController *)viewController options:(StorageProviderReadOptions *)options completion:(StorageProviderReadCompletionBlock)completionHandler {
    
}

- (DatabasePreferences *)getDatabasePreferences:(NSString *)nickName providerData:(NSObject *)providerData {
    LocalDatabaseIdentifier* identifier = (LocalDatabaseIdentifier*)providerData;
    
    return [DatabasePreferences templateDummyWithNickName:nickName
                                          storageProvider:self.storageId
                                                 fileName:identifier.filename
                                           fileIdentifier:[identifier toJson]];
}

- (void)pullDatabase:(DatabasePreferences *)safeMetaData
       interactiveVC:(UIViewController *)viewController
             options:(StorageProviderReadOptions *)options
          completion:(StorageProviderReadCompletionBlock)completion {
    NSURL *url = [self getFileUrl:safeMetaData];
    
    slog(@"Local Reading at: %@", url);
    
    NSError* error;
    NSDictionary* attributes = [NSFileManager.defaultManager attributesOfItemAtPath:url.path error:&error];
    
    if (error) {
        slog(@"Error = [%@]", error);
        completion(kReadResultError, nil, nil, error);
    }
    else {
        if (options.onlyIfModifiedDifferentFrom == nil || (![attributes.fileModificationDate isEqualToDateWithinEpsilon:options.onlyIfModifiedDifferentFrom] )) {
            NSData *data = [[NSFileManager defaultManager] contentsAtPath:url.path];
            completion(kReadResultSuccess, data, attributes.fileModificationDate, error);
        }
        else {
            completion(kReadResultModifiedIsSameAsLocal, nil, nil, nil);
        }
    }
}

- (void)getModDate:(nonnull METADATA_PTR)safeMetaData completion:(nonnull StorageProviderGetModDateCompletionBlock)completion {
    slog(@"🔴 LocalDeviceStorageProvider::getModDate not impl!"); 
    
    
}



- (LocalDatabaseIdentifier*)getIdentifierFromMetadata:(DatabasePreferences*)metaData {
    NSString* json = metaData.fileIdentifier;
    return [LocalDatabaseIdentifier fromJson:json];
}

- (NSURL*)getDirectory:(BOOL)shared {
    return shared ? StrongboxFilesManager.sharedInstance.sharedAppGroupDirectory : StrongboxFilesManager.sharedInstance.documentsDirectory;
}

- (NSURL*)getFileUrl:(DatabasePreferences*)safeMetaData {
    LocalDatabaseIdentifier* identifier = [self getIdentifierFromMetadata:safeMetaData];
    return [self getFileUrl:identifier.sharedStorage filename:identifier.filename];
}

- (NSURL*)getFileUrl:(BOOL)sharedStorage filename:(NSString*)filename {
    NSURL* folder = [self getDirectory:sharedStorage];
    return [folder URLByAppendingPathComponent:filename];
}

- (NSURL*)getDefaultStorageFileUrl:(NSString*)filename {
    NSURL* folder = [self getDirectory:YES];
    return [folder URLByAppendingPathComponent:filename];
}

- (NSURL*)getDocumentsFileUrl:(NSString*)filename {
    NSURL* folder = [self getDirectory:NO];
    return [folder URLByAppendingPathComponent:filename];
}

- (BOOL)fileNameExistsInDocumentsFolder:(NSString*)filename {
    NSURL *fullPath = [self getDocumentsFileUrl:filename];
    return [[NSFileManager defaultManager] fileExistsAtPath:fullPath.path];
}

- (BOOL)fileNameExistsInDefaultStorage:(NSString*)filename {
    NSURL *fullPath = [self getDefaultStorageFileUrl:filename];
    return [[NSFileManager defaultManager] fileExistsAtPath:fullPath.path];
}

- (BOOL)isUsingSharedStorage:(DatabasePreferences*)metadata {
    LocalDatabaseIdentifier* identifier = [self getIdentifierFromMetadata:metadata];
    return identifier.sharedStorage;
}

- (BOOL)renameFilename:(DatabasePreferences*)database filename:(NSString*)filename error:(NSError**)error {
    NSURL* url = [self getFileUrl:database];
    NSString* fullPath = url.absoluteURL.path;
    NSString* oldExtension = fullPath.pathExtension;
    
    NSString* stripped = [MMcGSwiftUtils stripInvalidFilenameCharacters:filename];
    NSString* sanitisedFilename = [stripped stringByAppendingPathExtension:oldExtension ? oldExtension : @""];
    
    NSString* baseDir = fullPath.stringByDeletingLastPathComponent;
    NSString* newPath = [baseDir stringByAppendingPathComponent:sanitisedFilename];
    
    if ( [NSFileManager.defaultManager fileExistsAtPath:newPath] ) {
        slog(@"🔴 Problem renaming local file!");
        
        if ( error ) {
            *error = [Utils createNSError:NSLocalizedString(@"error_rename_file_already_exists", @"Cannot rename file as a file with that name already exists.") errorCode:-1234];
        }
        
        return NO;
    }
    
    LocalDatabaseIdentifier* identifier = [self getIdentifierFromMetadata:database];
    identifier.filename = sanitisedFilename;
    
    
    
    NSError* err;
    if (! [NSFileManager.defaultManager moveItemAtPath:fullPath toPath:newPath error:&err] ) {
        slog(@"🔴 Problem renaming local file! [%@]", err);
        
        if ( error ) {
            *error = err;
        }
        
        return NO;
    }
    
    
    
    database.fileName = identifier.filename;
    database.fileIdentifier = [identifier toJson];
    
    return YES;
}

@end
