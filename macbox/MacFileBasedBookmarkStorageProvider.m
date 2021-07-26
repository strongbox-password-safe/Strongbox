//
//  MacFileBasedBookmarkStorageProvider.m
//  MacBox
//
//  Created by Strongbox on 22/03/2021.
//  Copyright © 2021 Mark McGuill. All rights reserved.
//

#import "MacFileBasedBookmarkStorageProvider.h"
#import "BookmarksHelper.h"
#import "DatabasesManager.h"
#import "Utils.h"
#import "MacUrlSchemes.h"

@implementation MacFileBasedBookmarkStorageProvider

+ (instancetype)sharedInstance {
    static MacFileBasedBookmarkStorageProvider *sharedInstance = nil;
    static dispatch_once_t onceToken;
    
    dispatch_once(&onceToken, ^{
        sharedInstance = [[MacFileBasedBookmarkStorageProvider alloc] init];
    });
    
    return sharedInstance;
}

- (instancetype)init {
    if (self = [super init]) {
        _storageId = kMacFile;
        _providesIcons = NO;
        _browsableNew = NO;
        _browsableExisting = NO;
        _rootFolderOnly = NO;
        _defaultForImmediatelyOfferOfflineCache = NO; 
        _supportsConcurrentRequests = NO; 
    }
    
    return self;
}

- (void)create:(nonnull NSString *)nickName extension:(nonnull NSString *)extension data:(nonnull NSData *)data parentFolder:(NSObject * _Nullable)parentFolder viewController:(VIEW_CONTROLLER_PTR _Nullable)viewController completion:(nonnull void (^)(METADATA_PTR _Nonnull, const NSError * _Nonnull))completion {
    
}

- (void)delete:(nonnull METADATA_PTR)safeMetaData completion:(nonnull void (^)(const NSError * _Nullable))completion {
    
}

- (METADATA_PTR _Nullable)getSafeMetaData:(nonnull NSString *)nickName providerData:(nonnull NSObject *)providerData {
    return nil;
}

- (void)list:(NSObject * _Nullable)parentFolder viewController:(VIEW_CONTROLLER_PTR _Nullable)viewController completion:(nonnull void (^)(BOOL, NSArray<StorageBrowserItem *> * _Nonnull, const NSError * _Nonnull))completion {
    
}

- (void)loadIcon:(nonnull NSObject *)providerData viewController:(nonnull VIEW_CONTROLLER_PTR)viewController completion:(nonnull void (^)(IMAGE_TYPE_PTR _Nonnull))completionHandler {
    
}

- (void)pullDatabase:(nonnull METADATA_PTR)safeMetaData interactiveVC:(VIEW_CONTROLLER_PTR _Nullable)viewController options:(nonnull StorageProviderReadOptions *)options completion:(nonnull StorageProviderReadCompletionBlock)completion {

    
    NSError *error;
    NSURL* url = [self directFileUrlForDatabase:safeMetaData ppError:&error];
    
    if(error || !url) {
        NSLog(@"Error or nil URL in Files App Provider: %@", error);
        completion(kReadResultError, nil, nil, error);
        return;
    }

    BOOL securitySucceeded = [url startAccessingSecurityScopedResource];
    if (!securitySucceeded) {
        
        NSLog(@"Could not access secure scoped resource! Will try get attributes anyway...");
    }
    
    NSDictionary* attr = [NSFileManager.defaultManager attributesOfItemAtPath:url.path error:&error];
    if (error) {
        
        NSLog(@"Error getting attributes for files based Database, will try open anyway: [%@] - Attributes: [%@]", error, attr);
    }

    NSError *readError = nil;
    NSData* data = [NSData dataWithContentsOfURL:url options:kNilOptions error:&readError];
    
    if ( securitySucceeded ) {
        [self stopAccessingSecurityScopedResource:url];
    }
    

    
    if ( data && !readError ) {
        completion(kReadResultSuccess, data, attr ? attr.fileModificationDate : nil, nil);
    }
    else {

        completion(kReadResultError, nil, nil, readError);
    }
}

- (void)getModDate:(METADATA_PTR)safeMetaData completion:(StorageProviderGetModDateCompletionBlock)completion {
    NSError *error;
    NSURL* url = [self directFileUrlForDatabase:safeMetaData ppError:&error];
    
    if(error || !url) {
        NSLog(@"Error or nil URL in Files App Provider: %@", error);
        completion(nil, error);
        return;
    }

    BOOL securitySucceeded = [url startAccessingSecurityScopedResource];
    if (!securitySucceeded) {
        
        NSLog(@"Could not access secure scoped resource! Will try get attributes anyway...");
    }
    
    NSDictionary* attr = [NSFileManager.defaultManager attributesOfItemAtPath:url.path error:&error];
    if (error) {
        
        NSLog(@"Error getting attributes for files based Database, will try open anyway: [%@] - Attributes: [%@]", error, attr);
    }

    if ( securitySucceeded ) {
        [self stopAccessingSecurityScopedResource:url];
    }
    
    completion(attr.fileModificationDate, error);
}

- (void)pushDatabase:(nonnull METADATA_PTR)safeMetaData interactiveVC:(VIEW_CONTROLLER_PTR _Nullable)viewController data:(nonnull NSData *)data completion:(nonnull StorageProviderUpdateCompletionBlock)completion {


    NSError *error;
    NSURL* url = [self directFileUrlForDatabase:safeMetaData ppError:&error];
    
    if(error) {
        NSLog(@"Error or nil URL in Files App provider: [%@]", error);
        completion(kUpdateResultError, nil, error);
        return;
    }
    
    if(!url || url.absoluteString.length == 0) {
        NSLog(@"nil or empty URL in Files App provider");
        error = [Utils createNSError:[NSString stringWithFormat:@"Invalid URL in Files App Provider: %@", url] errorCode:-1];
        completion(kUpdateResultError, nil, error);
        return;
    }
    
    BOOL securitySucceeded = [url startAccessingSecurityScopedResource];
    if (!securitySucceeded) {
        
        NSLog(@"Could not access secure scoped resource! Will try get attributes anyway...");
    }
    
    BOOL success = [data writeToURL:url options:kNilOptions error:&error];
    NSDictionary* attr = [NSFileManager.defaultManager attributesOfItemAtPath:url.path error:&error];

    if (error) {
        
        NSLog(@"Error getting attributes for files based Database, will try open anyway: [%@] - Attributes: [%@]", error, attr);
    }

    if ( securitySucceeded ) {
        [self stopAccessingSecurityScopedResource:url];
    }
    
    if ( success ) {
        completion(kUpdateResultSuccess, attr ? attr.fileModificationDate : nil, nil);
    }
    else {
        NSError *err = [Utils createNSError:NSLocalizedString(@"files_provider_problem_saving", @"Problem Saving to External File") errorCode:-1];
        completion(kUpdateResultError, nil, err);
    }

}

- (void)readWithProviderData:(NSObject * _Nullable)providerData
              viewController:(VIEW_CONTROLLER_PTR _Nullable)viewController
                     options:(nonnull StorageProviderReadOptions *)options completion:(nonnull StorageProviderReadCompletionBlock)completionHandler {
    
}

- (NSURL*)directFileUrlForDatabase:(METADATA_PTR)database ppError:(NSError**)ppError {
    if ( database.storageInfo != nil ) {
        NSError *error = nil;
        NSString* updatedBookmark;
        NSURL *url = [BookmarksHelper getUrlFromBookmark:database.storageInfo
                                                readOnly:NO
                                         updatedBookmark:&updatedBookmark
                                                   error:&error];
    
        if( url == nil ) {
            NSLog(@"WARN: Could not resolve bookmark for database... will try the saved fileUrl...");
        }
        else {
            
    
            if ( updatedBookmark ) {
                NSLog(@"INFO: Bookmark has changed for Database updating...");
                database.storageInfo = updatedBookmark;
                [DatabasesManager.sharedInstance atomicUpdate:database.uuid touch:^(DatabaseMetadata * _Nonnull metadata) {
                    metadata.storageInfo = updatedBookmark;
                }];
            }
            
            NSURL* defaultRet = fileUrlFromManagedUrl(database.fileUrl);
            if ( ![url.absoluteString isEqualToString:defaultRet.absoluteString] ) {
                NSLog(@"INFO: URL has changed for Database updating...");

                database.fileUrl = managedUrlFromFileUrl(url);
                [DatabasesManager.sharedInstance atomicUpdate:database.uuid touch:^(DatabaseMetadata * _Nonnull metadata) {
                    metadata.fileUrl = database.fileUrl;
                }];
            }
            
            return url; 
        }
    }
    
    return fileUrlFromManagedUrl(database.fileUrl);
}

- (void)stopAccessingSecurityScopedResource:(NSURL*)url {
    if ( @available(macOS 11.0, *) ) { 
        [url stopAccessingSecurityScopedResource];
    }
}

@end
