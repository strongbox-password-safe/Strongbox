//
//  FilesAppUrlBookmarkProvider.m
//  Strongbox
//
//  Created by Mark on 05/12/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
//

#import "FilesAppUrlBookmarkProvider.h"
#import "StrongboxUIDocument.h"
#import "Utils.h"
#import "BookmarksHelper.h"
#import "SafesList.h"
#import "FileManager.h"
#import "iCloudSafesCoordinator.h"

typedef void (^CreateCompletionBlock)(SafeMetaData *metadata, NSError *error);

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
        _displayName = NSLocalizedString(@"storage_provider_name_ios_files", @"iOS Files");
        if([self.displayName isEqualToString:@"storage_provider_name_ios_files"]) {
            _displayName = @"iOS Files"; 
        }
        
        _icon = @"lock"; 
        _storageId = kFilesAppUrlBookmark;
        _allowOfflineCache = YES;
        _providesIcons = NO;
        _browsableNew = NO;
        _browsableExisting = NO;
        _rootFolderOnly = NO;
        _immediatelyOfferCacheIfOffline = NO; // Local on device files are available even if offline! Some third parties may provide cached files... - 25-May-2020
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
//    NSLog(@"Picked: [%@]", urls);

    [self onCreateDestinationSelected:urls.firstObject];
    
    [NSFileManager.defaultManager removeItemAtURL:self.createTemporaryDatabaseUrl error:nil];
}

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
        // Nop - Don't do anything Background watcher will pick up this new DB
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

- (void)delete:(SafeMetaData *)safeMetaData completion:(void (^)(NSError *))completion {
    // NOTIMPL
    NSLog(@"WARN: FilesAppUrlBookmarkProvider NOTIMPL");
    return;
}

- (SafeMetaData *)getSafeMetaData:(NSString *)nickName fileName:(NSString*)fileName providerData:(NSObject *)providerData {
    NSString* json = [self getJsonFileIdentifier:(NSData*)providerData autoFillBookmark:nil];
    
    return [[SafeMetaData alloc] initWithNickName:nickName
                                  storageProvider:self.storageId
                                         fileName:fileName
                                   fileIdentifier:json];
}

- (void)list:(NSObject *)parentFolder
viewController:(UIViewController *)viewController
  completion:(void (^)(BOOL, NSArray<StorageBrowserItem *> *, NSError *))completion {
    // NOTIMPL
    NSLog(@"WARN: FilesAppUrlBookmarkProvider NOTIMPL");
    return;
}

- (void)loadIcon:(NSObject *)providerData viewController:(UIViewController *)viewController completion:(void (^)(UIImage *))completionHandler {
    // NOTIMPL
}

- (void)read:(SafeMetaData *)safeMetaData viewController:(UIViewController *)viewController isAutoFill:(BOOL)isAutoFill completion:(void (^)(NSData * _Nullable, NSError * _Nullable))completion {
    //NSLog(@"READ! %@", safeMetaData);
    
    NSError *error;
    NSURL* url = [self filesAppUrlFromMetaData:safeMetaData isAutoFill:isAutoFill ppError:&error];
    
    if(error || !url) {
        NSLog(@"Error or nil URL in Files App Provider: %@", error);
        completion(nil, error);
        return;
    }

    BOOL securitySucceeded = [url startAccessingSecurityScopedResource];
    if (!securitySucceeded) {
        NSLog(@"Could not access secure scoped resource!");
        return;
    }
    
    StrongboxUIDocument *document = [[StrongboxUIDocument alloc] initWithFileURL:url];
    
    [document openWithCompletionHandler:^(BOOL success) {
        completion(success ? document.data : nil, nil);
        
        [url stopAccessingSecurityScopedResource];
    }];
}

- (void)readWithProviderData:(NSObject *)providerData viewController:(UIViewController *)viewController completion:(void (^)(NSData *, NSError *))completionHandler {
    // NOTIMPL:
    NSLog(@"WARN: FilesAppUrlBookmarkProvider NOTIMPL");
}

- (void)update:(SafeMetaData *)safeMetaData data:(NSData *)data isAutoFill:(BOOL)isAutoFill completion:(void (^)(NSError * _Nullable))completion {
    NSError *error;
    NSURL* url = [self filesAppUrlFromMetaData:safeMetaData isAutoFill:isAutoFill ppError:&error];
    
    if(error) {
        NSLog(@"Error or nil URL in Files App provider: [%@]", error);
        completion(error);
        return;
    }
    
    if(!url || url.absoluteString.length == 0) {
        NSLog(@"nil or empty URL in Files App provider");
        error = [Utils createNSError:[NSString stringWithFormat:@"Invalid URL in Files App Provider: %@", url] errorCode:-1];
        completion(error);
        return;
    }
    
    StrongboxUIDocument *document = [[StrongboxUIDocument alloc] initWithData:data fileUrl:url];
    
    [document saveToURL:url forSaveOperation:UIDocumentSaveForOverwriting completionHandler:^(BOOL success) {
        if(success) {
            NSLog(@"Done");
            completion(nil);
        }
        else {
            NSError *err = [Utils createNSError:NSLocalizedString(@"files_provider_problem_saving", @"Problem Saving to External File") errorCode:-1];
            completion(err);
        }
    }];
}

- (SafeMetaData *)getSafeMetaData:(NSString *)nickName providerData:(NSObject *)providerData {
    // NOTIMPL
    
    NSLog(@"WARN: FilesAppUrlBookmarkProvider NOTIMPL");
    
    return nil;
}

//

- (NSString*)getJsonFileIdentifier:(NSData*)bookmark autoFillBookmark:(NSData*)autoFillBookmark {
    NSString *base64 = [bookmark base64EncodedStringWithOptions:kNilOptions];
    NSString *base64AutoFill = [autoFillBookmark base64EncodedStringWithOptions:kNilOptions];
    
    NSDictionary* dp = autoFillBookmark ? @{ @"bookMark" : base64, @"autoFillBookMark" : base64AutoFill } : @{  @"bookMark" : base64 };
    
    NSError* error;
    NSData* data = [NSJSONSerialization dataWithJSONObject:dp options:0 error:&error];
    
    if(error) {
        NSLog(@"%@", error);
        return nil;
    }
    
    NSString *json = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    
    return json;
}

- (NSData*)bookMarkFromMetadata:(SafeMetaData*)metadata isAutoFill:(BOOL)isAutoFill {
    NSData* data = [metadata.fileIdentifier dataUsingEncoding:NSUTF8StringEncoding];
    
    NSError *error;
    NSDictionary* dictionary = (NSDictionary*)[NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
    
    if(error) {
        return nil;
    }
    
    NSString* b64 = isAutoFill ? dictionary[@"autoFillBookMark"] : dictionary[@"bookMark"];
    
    return b64 ? [[NSData alloc] initWithBase64EncodedString:b64 options:NSDataBase64DecodingIgnoreUnknownCharacters] : nil;
}

- (NSURL*)filesAppUrlFromMetaData:(SafeMetaData*)safeMetaData isAutoFill:(BOOL)isAutoFill ppError:(NSError**)ppError {
    NSData* bookmarkData = [self bookMarkFromMetadata:safeMetaData isAutoFill:isAutoFill];
    if(!bookmarkData) {
        NSLog(@"Bookmark not found in metadata... possibly autofill initial read?");
        return nil;
    }
    
    NSData* updatedBookmark; 
    NSURL* url = [BookmarksHelper getUrlFromBookmarkData:bookmarkData updatedBookmark:&updatedBookmark error:ppError];
    
    if(url && !*ppError && updatedBookmark) {
        NSLog(@"Bookmark was stale! Updating Database with new one...");
        
        NSData* mainAppBookmark;
        NSData* autoFillBookmark;
        
        if(isAutoFill) {
            mainAppBookmark = [self bookMarkFromMetadata:safeMetaData isAutoFill:NO];
            autoFillBookmark = updatedBookmark;
        }
        else {
            mainAppBookmark = updatedBookmark;
            autoFillBookmark = [self bookMarkFromMetadata:safeMetaData isAutoFill:YES];
        }

        safeMetaData.fileIdentifier = [self getJsonFileIdentifier:mainAppBookmark autoFillBookmark:autoFillBookmark];

        [SafesList.sharedInstance update:safeMetaData];
    }
    
    NSLog(@"Got URL from Bookmark: [%@]", url);
    
    return url;
}

- (BOOL)autoFillBookMarkIsSet:(SafeMetaData*)metadata {
    NSError* error;
    return [self filesAppUrlFromMetaData:metadata isAutoFill:YES ppError:&error] != nil;
}

- (SafeMetaData*)setAutoFillBookmark:(NSData *)bookmark metadata:(SafeMetaData *)metadata {
    NSData* originalBookmark = [self bookMarkFromMetadata:metadata isAutoFill:NO];
    
    NSString* fileIdentifier = [self getJsonFileIdentifier:originalBookmark autoFillBookmark:bookmark];
    
    metadata.fileIdentifier = fileIdentifier;
    
    return metadata;
}

@end
