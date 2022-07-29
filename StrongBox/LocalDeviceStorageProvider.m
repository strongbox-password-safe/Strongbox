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
#import "FileManager.h"
#import "LocalDatabaseIdentifier.h"
#import "NSDate+Extensions.h"

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
        _supportsConcurrentRequests = YES;
        
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
        completion:(void (^)(DatabasePreferences *metadata, NSError *error))completion {
    NSString *desiredFilename = [NSString stringWithFormat:@"%@.%@", nickName, extension];
    [self create:nickName extension:extension data:data modDate:NSDate.date suggestedFilename:desiredFilename completion:completion];
}

- (void)create:(NSString *)nickName
     extension:(NSString *)extension
          data:(NSData *)data
       modDate:(NSDate *)modDate
suggestedFilename:(NSString *)suggestedFilename
    completion:(void (^)(DatabasePreferences * _Nonnull, NSError *))completion {
    
    
    
    
    
    
    
    
    if(![self writeToDefaultStorageWithFilename:suggestedFilename overwrite:NO data:data modDate:nil]) {
        suggestedFilename = [NSString stringWithFormat:@"%@.%@", nickName, extension];
        while(![self writeToDefaultStorageWithFilename:suggestedFilename overwrite:NO data:data modDate:nil]) {
            suggestedFilename = [Utils insertTimestampInFilename:suggestedFilename];
        }
    }
    
    LocalDatabaseIdentifier *identifier = [[LocalDatabaseIdentifier alloc] init];
    identifier.filename = suggestedFilename;
    identifier.sharedStorage = YES;
    
    DatabasePreferences *metadata = [self getDatabasePreferences:nickName providerData:identifier];
    
    
    
    NSURL* url = [self getFileUrl:metadata];
    
    NSError *err2;
    [NSFileManager.defaultManager setAttributes:@{ NSFileModificationDate : modDate }
                                   ofItemAtPath:url.path
                                          error:&err2];
    
    NSLog(@"Set Local Device database Attributes for [%@] to [%@] with error = [%@]", metadata.nickName, modDate, err2);

    completion(metadata, nil);
}

- (BOOL)writeToDefaultStorageWithFilename:(NSString*)filename overwrite:(BOOL)overwrite data:(NSData *)data modDate:(NSDate*_Nullable)modDate {
    NSLog(@"Trying to write local file with filename [%@]", filename);
    NSString *path = [self getDefaultStorageFileUrl:filename].path;

    
    
    BOOL ret;
    if ([[NSFileManager defaultManager] fileExistsAtPath:path]) {
        
        if(overwrite) {
            
            ret = [self write:data path:path overwrite:overwrite];
        }
        else {
            
            NSLog(@"File [%@] but not allowed to overwrite...", filename);
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
                NSLog(@"WARNWARN: writeToDefaultStorageWithFilename -> could not set mod date: [%@]", err2);
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
        NSLog(@"tryWrite Failed: [%@]", error);
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

    NSError *error;

    [[NSFileManager defaultManager] removeItemAtPath:url.path error:&error];

    if(completion != nil) {
        completion(error);
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

    NSLog(@"Local Reading at: %@", url);

    NSError* error;
    NSDictionary* attributes = [NSFileManager.defaultManager attributesOfItemAtPath:url.path error:&error];
    
    if (error) {
        NSLog(@"Error = [%@]", error);
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
    NSLog(@"🔴 LocalDeviceStorageProvider::getModDate not impl!");

    
}



- (LocalDatabaseIdentifier*)getIdentifierFromMetadata:(DatabasePreferences*)metaData {
    NSString* json = metaData.fileIdentifier;
    return [LocalDatabaseIdentifier fromJson:json];
}

- (NSURL*)getDirectory:(BOOL)shared {
    return shared ? FileManager.sharedInstance.sharedAppGroupDirectory : FileManager.sharedInstance.documentsDirectory;
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

- (BOOL)fileNameExistsInDefaultStorage:(NSString*)filename {
    NSURL *fullPath = [self getDefaultStorageFileUrl:filename];
    return [[NSFileManager defaultManager] fileExistsAtPath:fullPath.path];
}

- (BOOL)isUsingSharedStorage:(DatabasePreferences*)metadata {
    LocalDatabaseIdentifier* identifier = [self getIdentifierFromMetadata:metadata];
    return identifier.sharedStorage;
}

@end
