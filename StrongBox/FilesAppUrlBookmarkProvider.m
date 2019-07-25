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
        _displayName = @"Files App URL Bookmark";
        _icon = @"lock"; 
        _storageId = kFilesAppUrlBookmark;
        _allowOfflineCache = YES;
        _providesIcons = NO;
        _browsableNew = NO;
        _browsableExisting = NO;
        _rootFolderOnly = NO;
    }
    
    return self;
}

- (void)create:(NSString *)nickName extension:(NSString *)extension data:(NSData *)data parentFolder:(NSObject *)parentFolder viewController:(UIViewController *)viewController completion:(void (^)(SafeMetaData *, NSError *))completion {
    // NOTIMPL:
    NSLog(@"WARN: FilesAppUrlBookmarkProvider NOTIMPL");
}

- (void)delete:(SafeMetaData *)safeMetaData completion:(void (^)(NSError *))completion {
    // NOTIMPL
    NSLog(@"WARN: FilesAppUrlBookmarkProvider NOTIMPL");
    return;
}

- (SafeMetaData *)getSafeMetaData:(NSString *)nickName fileName:(NSString*)fileName providerData:(NSObject *)providerData {
    NSString *base64 = [((NSData*)providerData)base64EncodedStringWithOptions:kNilOptions];
    NSDictionary* dp = [NSDictionary dictionaryWithObjectsAndKeys:base64, @"bookMark", nil];
    
    NSError* error;
    NSData* data = [NSJSONSerialization dataWithJSONObject:dp options:0 error:&error];
    
    if(error) {
        NSLog(@"%@", error);
        return nil;
    }
    
    NSString *json = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    
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

- (void)read:(SafeMetaData *)safeMetaData viewController:(UIViewController *)viewController completion:(void (^)(NSData *, NSError *))completion {
    //NSLog(@"READ! %@", safeMetaData);
    
    NSError *error;
    NSURL* url = [self filesAppUrlFromMetaData:safeMetaData ppError:&error];
    
    if(error || !url) {
        NSLog(@"%@", error);
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

- (void)update:(SafeMetaData *)safeMetaData data:(NSData *)data completion:(void (^)(NSError *))completion {
    NSError *error;
    NSURL* url = [self filesAppUrlFromMetaData:safeMetaData ppError:&error];
    
    if(error || !url) {
        NSLog(@"%@", error);
        completion(error);
    }
    
    StrongboxUIDocument *document = [[StrongboxUIDocument alloc] initWithData:data fileUrl:url];
    
    [document saveToURL:url forSaveOperation:UIDocumentSaveForOverwriting completionHandler:^(BOOL success) {
        if(success) {
            NSLog(@"Done");
            completion(nil);
        }
        else {
            NSError *err = [Utils createNSError:@"Problem Saving to External File" errorCode:-1];
            completion(err);
        }
    }];
}

- (SafeMetaData *)getSafeMetaData:(NSString *)nickName providerData:(NSObject *)providerData {
    // NOTIMPL
    
    NSLog(@"WARN: FilesAppUrlBookmarkProvider NOTIMPL");
    
    return nil;
}

- (NSData*)bookMarkFromMetadata:(SafeMetaData*)metadata {
    NSData* data = [metadata.fileIdentifier dataUsingEncoding:NSUTF8StringEncoding];
    
    NSError *error;
    NSDictionary* dictionary = (NSDictionary*)[NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
    
    if(error) {
        return nil;
    }
    
    NSString* b64 = [dictionary objectForKey:@"bookMark"];
    
    return [[NSData alloc] initWithBase64EncodedString:b64 options:kNilOptions];
}

- (NSURL*)filesAppUrlFromMetaData:(SafeMetaData*)safeMetaData ppError:(NSError**)ppError {
    NSData* bookmarkData = [self bookMarkFromMetadata:safeMetaData];
    
    NSError *error;
    BOOL bookmarkIsStale; // https://stackoverflow.com/questions/23954662/what-is-the-correct-way-to-handle-stale-nsurl-bookmarks
    NSURLBookmarkResolutionOptions options = NSURLBookmarkResolutionWithoutUI;
    
    NSURL *url = [NSURL URLByResolvingBookmarkData:bookmarkData
                                           options:options
                                     relativeToURL:nil
                               bookmarkDataIsStale:&bookmarkIsStale
                                             error:&error];
    
    if(bookmarkIsStale) {
        url = nil;
        error = [Utils createNSError:@"Strongbox's reference to this external file is stale. Please remove and re-add this database." errorCode:-45];   
    }
    
    if(error) {
        *ppError = error;
    }
    
    return url;
}

@end
