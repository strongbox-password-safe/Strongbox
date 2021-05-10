//
//  FilesAppUrlBookmarkProvider.m
//  Strongbox
//
//  Created by Mark on 05/12/2018.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import "FilesAppUrlBookmarkProvider.h"
#import "StrongboxUIDocument.h"
#import "Utils.h"
#import "BookmarksHelper.h"
#import "SafesList.h"
#import "FileManager.h"
#import "iCloudSafesCoordinator.h"
#import "NSDate+Extensions.h"

typedef void (^CreateCompletionBlock)(SafeMetaData *metadata, const NSError *error);

@interface FilesAppUrlBookmarkProvider () <UIDocumentPickerDelegate>

@property NSString* createNickName;
@property NSURL* createTemporaryDatabaseUrl;
@property CreateCompletionBlock createCompletion;

@end

@implementation FilesAppUrlBookmarkProvider

+ (instancetype)sharedInstance {
    static FilesAppUrlBookmarkProvider *sharedInstance = nil;
    static dispatch_once_t onceToken;
    
    dispatch_once(&onceToken, ^{
        sharedInstance = [[FilesAppUrlBookmarkProvider alloc] init];
    });
    return sharedInstance;
}

- (instancetype)init {
    if (self = [super init]) {
        _storageId = kFilesAppUrlBookmark;
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
     extension:(NSString *)extension
          data:(NSData *)data
  parentFolder:(NSObject *)parentFolder
viewController:(UIViewController *)viewController completion:(CreateCompletionBlock)completion {
    NSString *desiredFilename = [NSString stringWithFormat:@"%@.%@", nickName, extension];

    NSString* f = [NSTemporaryDirectory() stringByAppendingPathComponent:desiredFilename];

    NSError* error;
    if (![NSFileManager.defaultManager removeItemAtPath:f error:&error] ) {
        completion(nil, error);
    }

    if (![data writeToFile:f options:kNilOptions error:&error]) {
        completion(nil, error);
    }
    
    self.createTemporaryDatabaseUrl = [NSURL fileURLWithPath:f];
    self.createCompletion = completion;
    self.createNickName = nickName;
    
    UIDocumentPickerViewController* vc = [[UIDocumentPickerViewController alloc] initWithURL:self.createTemporaryDatabaseUrl inMode:UIDocumentPickerModeExportToService];
    vc.delegate = self;
    
    [viewController presentViewController:vc animated:YES completion:nil];
}

- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls {
    NSLog(@"didPickDocumentsAtURLs: %@", urls);
    
    NSURL* url = [urls objectAtIndex:0];

    #pragma GCC diagnostic push
    #pragma GCC diagnostic ignored "-Wdeprecated-declarations"
    [self documentPicker:controller didPickDocumentAtURL:url];
    #pragma GCC diagnostic pop
}

#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wdeprecated-implementations"
- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentAtURL:(NSURL *)url { 
    [self onCreateDestinationSelected:url];
    
    [NSFileManager.defaultManager removeItemAtURL:self.createTemporaryDatabaseUrl error:nil];
}
#pragma GCC diagnostic pop

- (void)documentPickerWasCancelled:(UIDocumentPickerViewController *)controller {
    [NSFileManager.defaultManager removeItemAtURL:self.createTemporaryDatabaseUrl error:nil];
}

- (void)onCreateDestinationSelected:(NSURL*)dest {
    [dest startAccessingSecurityScopedResource];

    NSURL *strongboxLocalDocumentsDirectory = FileManager.sharedInstance.documentsDirectory;
    NSString *strongboxLocalDocumentsPath = strongboxLocalDocumentsDirectory.URLByStandardizingPath.URLByResolvingSymlinksInPath.path;

    NSURL* strongboxICloudDocumentsDirectory = iCloudSafesCoordinator.sharedInstance.iCloudDocumentsFolder;
    NSString* strongboxICloudDocumentsPath = strongboxICloudDocumentsDirectory ? strongboxICloudDocumentsDirectory.URLByStandardizingPath.URLByResolvingSymlinksInPath.path : nil;
    
    NSString *filePath = dest.URLByStandardizingPath.URLByResolvingSymlinksInPath.path;
    NSString *fileParentPath = [filePath stringByDeletingLastPathComponent];
    
    NSLog(@"[%@] == [%@]", strongboxICloudDocumentsPath, fileParentPath);

    BOOL isLocalSandboxFile = [fileParentPath isEqualToString:strongboxLocalDocumentsPath];
    BOOL isStrongboxICloudFile = strongboxICloudDocumentsPath ? [fileParentPath isEqualToString:strongboxICloudDocumentsPath] : NO;

    if (isLocalSandboxFile || isStrongboxICloudFile) {
        
        NSLog(@"New Database is actually local to Sandbox or iCloud - using simplified non iOS Files Storage Provider. [%d][%d]", isLocalSandboxFile, isStrongboxICloudFile);
    }
    else {
        NSError* error;
        NSData* bookmark = [BookmarksHelper getBookmarkDataFromUrl:dest error:&error];
        
        if (bookmark) {
            NSString* desiredFilename = dest.lastPathComponent;
            SafeMetaData* metadata = [self getSafeMetaData:self.createNickName fileName:desiredFilename providerData:bookmark];
            self.createCompletion(metadata, nil);
        }
        else {
            NSLog(@"Error creating bookmark for iOS Files based database: [%@] - [%@]", error, dest);
            self.createCompletion(nil, error);
            return;
        }
    }
}

- (void)delete:(SafeMetaData *)safeMetaData completion:(void (^)(const NSError *))completion {
    
    NSLog(@"WARN: FilesAppUrlBookmarkProvider NOTIMPL");
    return;
}

- (SafeMetaData *)getSafeMetaData:(NSString *)nickName fileName:(NSString*)fileName providerData:(NSObject *)providerData {
    NSString* json = [self getJsonFileIdentifier:(NSData*)providerData];
    
    return [[SafeMetaData alloc] initWithNickName:nickName
                                  storageProvider:self.storageId
                                         fileName:fileName
                                   fileIdentifier:json];
}

- (void)list:(NSObject *)parentFolder
viewController:(UIViewController *)viewController
  completion:(void (^)(BOOL, NSArray<StorageBrowserItem *> *, const NSError *))completion {
    
    NSLog(@"WARN: FilesAppUrlBookmarkProvider NOTIMPL");
    return;
}

- (void)loadIcon:(NSObject *)providerData viewController:(UIViewController *)viewController completion:(void (^)(UIImage *))completionHandler {
    
}

- (void)pullDatabase:(SafeMetaData *)safeMetaData interactiveVC:(UIViewController *)viewController options:(StorageProviderReadOptions *)options completion:(StorageProviderReadCompletionBlock)completion {
    
    
    NSError *error;
    NSURL* url = [self filesAppUrlFromMetaData:safeMetaData ppError:&error];
    
    if(error || !url) {
        NSLog(@"Error or nil URL in Files App Provider: %@", error);
        completion(kReadResultError, nil, nil, error);
        return;
    }

    BOOL securitySucceeded = [url startAccessingSecurityScopedResource];
    if (!securitySucceeded) {
        
        NSLog(@"Could not access secure scoped resource! Will try get attributes anyway...");
    }







    dispatch_async(dispatch_get_main_queue(), ^{ 
        StrongboxUIDocument *document = [[StrongboxUIDocument alloc] initWithFileURL:url];
        
        if (!document) {
            completion(kReadResultError, nil, nil, error ? error : [Utils createNSError:@"Invalid Files URL" errorCode:-6]);
            return;
        }

        [document openWithCompletionHandler:^(BOOL success) {
            if (!success) {
                completion(kReadResultError, nil, nil, error);
            }
            else {
                if ( options && options.onlyIfModifiedDifferentFrom && document.fileModificationDate && [document.fileModificationDate isEqualToDateWithinEpsilon:options.onlyIfModifiedDifferentFrom] ) {
                    completion(kReadResultModifiedIsSameAsLocal, nil, nil, nil);
                }
                else {
                    completion(kReadResultSuccess, document.data, document.fileModificationDate, nil );
                }
            }
            
            [url stopAccessingSecurityScopedResource];
            
            [document closeWithCompletionHandler:nil];
        }];
    });
}

- (void)readWithProviderData:(NSObject *)providerData viewController:(UIViewController *)viewController options:(StorageProviderReadOptions *)options completion:(StorageProviderReadCompletionBlock)completionHandler {
    
    NSLog(@"WARN: FilesAppUrlBookmarkProvider NOTIMPL");
}

- (void)pushDatabase:(SafeMetaData *)safeMetaData interactiveVC:(UIViewController *)viewController data:(NSData *)data completion:(StorageProviderUpdateCompletionBlock)completion {
    NSError *error;
    NSURL* url = [self filesAppUrlFromMetaData:safeMetaData ppError:&error];
    
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
    
    dispatch_async(dispatch_get_main_queue(), ^{ 
        StrongboxUIDocument *document = [[StrongboxUIDocument alloc] initWithData:data fileUrl:url];
        
        [document saveToURL:url forSaveOperation:UIDocumentSaveForOverwriting completionHandler:^(BOOL success) {
            if(success) {
                NSLog(@"Done");
                completion(kUpdateResultSuccess, document.fileModificationDate, nil);
            }
            else {
                NSError *err = [Utils createNSError:NSLocalizedString(@"files_provider_problem_saving", @"Problem Saving to External File") errorCode:-1];
                completion(kUpdateResultError, nil, err);
            }
            
            [document closeWithCompletionHandler:nil];
        }];
    });
}

- (SafeMetaData *)getSafeMetaData:(NSString *)nickName providerData:(NSObject *)providerData {
    
    
    NSLog(@"WARN: FilesAppUrlBookmarkProvider NOTIMPL");
    
    return nil;
}

- (void)getModDate:(nonnull METADATA_PTR)safeMetaData completion:(nonnull StorageProviderGetModDateCompletionBlock)completion {
    
}




- (NSString*)getJsonFileIdentifier:(NSData*)bookmark {
    NSString *base64 = [bookmark base64EncodedStringWithOptions:kNilOptions];
    
    NSDictionary* dp = @{  @"bookMark" : base64 };
    
    NSError* error;
    NSData* data = [NSJSONSerialization dataWithJSONObject:dp options:0 error:&error];
    
    if(error) {
        NSLog(@"%@", error);
        return nil;
    }
    
    NSString *json = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    
    return json;
}

- (NSData*)bookMarkFromMetadata:(SafeMetaData*)metadata {
    NSData* data = [metadata.fileIdentifier dataUsingEncoding:NSUTF8StringEncoding];
    
    NSError *error;
    NSDictionary* dictionary = (NSDictionary*)[NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
    
    if(error) {
        return nil;
    }
    
    NSString* b64 = dictionary[@"bookMark"];
    
    return b64 ? [[NSData alloc] initWithBase64EncodedString:b64 options:NSDataBase64DecodingIgnoreUnknownCharacters] : nil;
}

- (NSURL*)filesAppUrlFromMetaData:(SafeMetaData*)safeMetaData ppError:(NSError**)ppError {
    NSData* bookmarkData = [self bookMarkFromMetadata:safeMetaData];
    if(!bookmarkData) {
        NSLog(@"Bookmark not found in metadata...");
        return nil;
    }
    
    NSData* updatedBookmark; 
    NSURL* url = [BookmarksHelper getUrlFromBookmarkData:bookmarkData updatedBookmark:&updatedBookmark error:ppError];
    
    if(url && !*ppError && updatedBookmark) {
        NSLog(@"Bookmark was stale! Updating Database with new one...");
        
        NSData* mainAppBookmark = updatedBookmark;

        safeMetaData.fileIdentifier = [self getJsonFileIdentifier:mainAppBookmark];
        [SafesList.sharedInstance update:safeMetaData];
    }
    
    NSLog(@"Got URL from Bookmark: [%@]", url);
    
    return url;
}

@end
