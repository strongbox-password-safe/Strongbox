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
        _displayName = @"iOS Files";
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
    
    if(error || !url) {
        NSLog(@"Error or nil URL in Files App provider: [%@]", error);
        completion(error);
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
    
    return b64 ? [[NSData alloc] initWithBase64EncodedString:b64 options:kNilOptions] : nil;
}

- (NSURL*)filesAppUrlFromMetaData:(SafeMetaData*)safeMetaData isAutoFill:(BOOL)isAutoFill ppError:(NSError**)ppError {
    NSData* bookmarkData = [self bookMarkFromMetadata:safeMetaData isAutoFill:isAutoFill];
    if(!bookmarkData) {
        NSLog(@"Bookmark not found in metadata... possibly autofill initial read?");
        return nil;
    }
    
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
        error = [Utils createNSError:NSLocalizedString(@"files_provider_stale_reference", @"Strongbox's reference to this external file is stale. Please remove and re-add this database.") errorCode:-45];   
    }
    
    if(error) {
        *ppError = error;
    }
    
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
