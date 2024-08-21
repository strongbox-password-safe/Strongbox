//
//  MacFileBasedBookmarkStorageProvider.m
//  MacBox
//
//  Created by Strongbox on 22/03/2021.
//  Copyright © 2021 Mark McGuill. All rights reserved.
//

#import "MacFileBasedBookmarkStorageProvider.h"
#import "BookmarksHelper.h"
#import "Utils.h"
#import "MacUrlSchemes.h"
#import "NSDate+Extensions.h"

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
        _storageId = kLocalDevice;
        _providesIcons = NO;
        _browsableNew = NO;
        _browsableExisting = NO;
        _rootFolderOnly = NO;
        _defaultForImmediatelyOfferOfflineCache = NO; 
        _supportsConcurrentRequests = NO; 
    }
    
    return self;
}

- (void)create:(NSString *)nickName 
      fileName:(NSString *)fileName 
          data:(NSData *)data
  parentFolder:(NSObject *)parentFolder
viewController:(VIEW_CONTROLLER_PTR)viewController
    completion:(void (^)(METADATA_PTR _Nullable, const NSError * _Nullable))completion {
    NSURL* userSelectedSaveUrl = (NSURL*)parentFolder;
    
    NSError* error = nil;
    BOOL success = [data writeToURL:userSelectedSaveUrl options:kNilOptions error:&error];
    if ( !success ) {
        slog(@"🔴 MacFileBasedBookmarkStorageProvider - Error Saving New Database: [%@]", error);
        completion ( nil, error );
        return;
    }
    
    NSString * fileIdentifier = [BookmarksHelper getBookmarkFromUrl:userSelectedSaveUrl readOnly:NO error:&error];
    
    if (!fileIdentifier) {
        slog(@"🔴 MacFileBasedBookmarkStorageProvider - Could not get Bookmark for this database at [%@]... [%@]", userSelectedSaveUrl, error);
        completion(nil, error);
        return;
    }
    
    NSURL* managedSyncUrl = managedUrlFromFileUrl(userSelectedSaveUrl);

    MacDatabasePreferences *ret = [MacDatabasePreferences templateDummyWithNickName:nickName
                                                                    storageProvider:kLocalDevice
                                                                            fileUrl:managedSyncUrl
                                                                        storageInfo:fileIdentifier];
    
    completion(ret, nil);
}

- (void)delete:(nonnull METADATA_PTR)safeMetaData completion:(nonnull void (^)(const NSError * _Nullable))completion {
    
}

- (void)list:(NSObject * _Nullable)parentFolder viewController:(VIEW_CONTROLLER_PTR _Nullable)viewController completion:(nonnull void (^)(BOOL, NSArray<StorageBrowserItem *> * _Nonnull, const NSError * _Nonnull))completion {
    
}

- (void)loadIcon:(nonnull NSObject *)providerData viewController:(nonnull VIEW_CONTROLLER_PTR)viewController completion:(nonnull void (^)(IMAGE_TYPE_PTR _Nonnull))completionHandler {
    
}

- (void)pullDatabase:(nonnull METADATA_PTR)safeMetaData 
       interactiveVC:(VIEW_CONTROLLER_PTR _Nullable)viewController
             options:(nonnull StorageProviderReadOptions *)options
          completion:(nonnull StorageProviderReadCompletionBlock)completion {

    
    NSError *error;
    NSURL* url = [self directFileUrlForDatabase:safeMetaData ppError:&error];
    
    if(error || !url) {
        slog(@"Error or nil URL in Files App Provider: %@", error);
        completion(kReadResultError, nil, nil, error);
        return;
    }

    BOOL securitySucceeded = [url startAccessingSecurityScopedResource];
    if (!securitySucceeded) {
        
        slog(@"Could not access secure scoped resource! Will try get attributes anyway...");
    }
    
    NSDictionary* attr = [NSFileManager.defaultManager attributesOfItemAtPath:url.path error:&error];
    NSDate* modDate = attr ? attr.fileModificationDate : nil;
    if (error) {
        
        slog(@"Error getting attributes for files based Database, will try open anyway: [%@] - Attributes: [%@]", error, attr);
    }
    else {
        if ( options && options.onlyIfModifiedDifferentFrom && modDate && [modDate isEqualToDateWithinEpsilon:options.onlyIfModifiedDifferentFrom] ) {
            if ( securitySucceeded ) {
                [self stopAccessingSecurityScopedResource:url];
            }

            completion(kReadResultModifiedIsSameAsLocal, nil, nil, nil);

            return;
        }
    }

    NSError *readError = nil;
    NSData* data = [NSData dataWithContentsOfURL:url options:kNilOptions error:&readError];
    
    if ( securitySucceeded ) {
        [self stopAccessingSecurityScopedResource:url];
    }
    

    
    if ( data && !readError ) {
        completion(kReadResultSuccess, data, modDate, nil);
    }
    else {

        completion(kReadResultError, nil, nil, readError);
    }
}

- (void)getModDate:(METADATA_PTR)safeMetaData completion:(StorageProviderGetModDateCompletionBlock)completion {
    NSError *error;
    NSURL* url = [self directFileUrlForDatabase:safeMetaData ppError:&error];
    
    if(error || !url) {
        slog(@"Error or nil URL in Files App Provider: %@", error);
        completion(YES, nil, error);
        return;
    }

    BOOL securitySucceeded = [url startAccessingSecurityScopedResource];
    if (!securitySucceeded) {
        
        slog(@"Could not access secure scoped resource! Will try get attributes anyway...");
    }
    
    NSDictionary* attr = [NSFileManager.defaultManager attributesOfItemAtPath:url.path error:&error];
    if (error) {
        
        slog(@"Error getting attributes for files based Database, will try open anyway: [%@] - Attributes: [%@]", error, attr);
    }

    if ( securitySucceeded ) {
        [self stopAccessingSecurityScopedResource:url];
    }
    
    completion(YES, attr.fileModificationDate, error);
}

- (void)pushDatabase:(nonnull METADATA_PTR)safeMetaData interactiveVC:(VIEW_CONTROLLER_PTR _Nullable)viewController data:(nonnull NSData *)data completion:(nonnull StorageProviderUpdateCompletionBlock)completion {


    NSError *error;
    NSURL* url = [self directFileUrlForDatabase:safeMetaData ppError:&error];
    
    if(error) {
        slog(@"Error or nil URL in Files App provider: [%@]", error);
        completion(kUpdateResultError, nil, error);
        return;
    }
    
    if(!url || url.absoluteString.length == 0) {
        slog(@"nil or empty URL in Files App provider");
        error = [Utils createNSError:[NSString stringWithFormat:@"Invalid URL in Files App Provider: %@", url] errorCode:-1];
        completion(kUpdateResultError, nil, error);
        return;
    }
    
    BOOL securitySucceeded = [url startAccessingSecurityScopedResource];
    if (!securitySucceeded) {
        
        slog(@"Could not access secure scoped resource! Will try get attributes anyway...");
    }
    
    BOOL success = [data writeToURL:url options:kNilOptions error:&error];
    if ( !success ) {
        if ( securitySucceeded ) {
            [self stopAccessingSecurityScopedResource:url];
        }
        
        completion(kUpdateResultError, nil, error);
    }
    else {
        NSDictionary* attr = [NSFileManager.defaultManager attributesOfItemAtPath:url.path error:&error];
        if (error) {
            
            slog(@"Error getting attributes for files based Database, will try open anyway: [%@] - Attributes: [%@]", error, attr);
        }
        
        if ( securitySucceeded ) {
            [self stopAccessingSecurityScopedResource:url];
        }
        
        if ( success ) {
            completion(kUpdateResultSuccess, attr ? attr.fileModificationDate : nil, nil);
        }
        else {
            NSError *err = error ? error : [Utils createNSError:NSLocalizedString(@"files_provider_problem_saving", @"Problem Saving to External File") errorCode:-1];
            completion(kUpdateResultError, nil, err);
        }
    }
}

- (void)readWithProviderData:(NSObject * _Nullable)providerData
              viewController:(VIEW_CONTROLLER_PTR _Nullable)viewController
                     options:(nonnull StorageProviderReadOptions *)options completion:(nonnull StorageProviderReadCompletionBlock)completionHandler {
    
}

- (METADATA_PTR _Nullable)getDatabasePreferences:(nonnull NSString *)nickName providerData:(nonnull NSObject *)providerData {
    return nil;
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
            slog(@"⚠️ WARN: Could not resolve bookmark for database... will try the saved fileUrl... Error = [%@], updatedBookmark = [%@]", error, updatedBookmark);
        }
        else {
            
    
            if ( updatedBookmark ) {
                slog(@"INFO: Bookmark has changed for Database updating...");
                database.storageInfo = updatedBookmark;
            }
            
            NSURL* defaultRet = fileUrlFromManagedUrl(database.fileUrl);
            if ( ![url.absoluteString isEqualToString:defaultRet.absoluteString] ) {
                slog(@"INFO: URL has changed for Database updating...");

                database.fileUrl = managedUrlFromFileUrl(url);
            }
            
            return url; 
        }
    }
    
    return fileUrlFromManagedUrl(database.fileUrl);
}

- (void)stopAccessingSecurityScopedResource:(NSURL*)url {
    [url stopAccessingSecurityScopedResource];
}

@end
