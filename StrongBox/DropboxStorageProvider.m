//
//  DropboxStorageProvider.m
//  StrongBox
//
//  Created by Mark on 19/11/2014.
//  Copyright (c) 2014 Mark McGuill. All rights reserved.
//

#import "DropboxStorageProvider.h"
#import "core-model/Utils.h"

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// PendingDropboxOperation - Helper / Container Class

@interface PendingDropboxOperation : NSObject

//@property UIViewController* viewController;
@property SafeMetaData *safeMetaData;
@property NSData *saveData;

@property (nonatomic, copy) void (^ readCompletion)(NSData *data, NSError *error);
@property (nonatomic, copy) void (^ updateCompletion)(NSError *error);
@property (nonatomic, copy) void (^ createCompletion)(NSString *fileName, NSString *fileIdentifier, NSError *error);

- (id)initForRead:(UIViewController *)viewController safe:(SafeMetaData *)safe completion:(void (^)(NSData *data, NSError *error))completion;
- (id)initForUpdate:(UIViewController *)viewController safe:(SafeMetaData *)safe data:(NSData *)data completion:(void (^)(NSError *error))completion;
- (id)initForCreate:(UIViewController *)viewController data:(NSData *)data completion:(void (^)(NSString *fileName, NSString *fileIdentifier, NSError *error))completion;

@end

@implementation PendingDropboxOperation

- (id)initForRead:(UIViewController *)viewController safe:(SafeMetaData *)safe completion:(void (^)(NSData *data, NSError *error))completion {
    // self.viewController = viewController;
    self.safeMetaData = safe;
    self.readCompletion = completion;

    return self;
}

- (id)initForUpdate:(UIViewController *)viewController safe:(SafeMetaData *)safe data:(NSData *)data completion:(void (^)(NSError *error))completion {
    //self.viewController = viewController;
    self.safeMetaData = safe;
    self.updateCompletion = completion;
    self.saveData = data;

    return self;
}

- (id)initForCreate:(UIViewController *)viewController data:(NSData *)data completion:(void (^)(NSString *fileName, NSString *fileIdentifier, NSError *error))completion {
    //self.viewController = viewController;
    self.createCompletion = completion;
    self.saveData = data;

    return self;
}

@end

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@implementation DropboxStorageProvider {
    PendingDropboxOperation *_pendingOperation;

    void (^ _afterDropboxLinkedCompletion)(BOOL success);
    DBRestClient *_restClient;
}

- (id)init {
    if (self = [super init]) {
        _displayName = @"Dropbox";
        _storageId = kDropbox;
        _cloudBased = YES;
        return self;
    }
    else {
        return nil;
    }
}

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)isDropboxLinkedHandle2:(id)sender {
    [[NSNotificationCenter defaultCenter] removeObserver:self];

    if ([[DBSession sharedSession] isLinked]) {
        NSLog(@"Main -> Dropbox linked ok");
    }
    else {
        NSLog(@"Dropbox Not Linked");
    }

    _afterDropboxLinkedCompletion([[DBSession sharedSession] isLinked]);
}

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)       create:(NSString *)desiredFilename data:(NSData *)data parentReference:(NSString *)parentReference viewController:(UIViewController *)viewController
    completionHandler:(void (^)(NSString *fileName, NSString *fileIdentifier, NSError *error))completion {
    _pendingOperation = [[PendingDropboxOperation alloc] initForCreate:viewController data:data completion:completion];

    if (![[DBSession sharedSession] isLinked]) {
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(isDropboxLinkedHandle2:) name:@"isDropboxLinked" object:nil];

        __weak typeof(self) weakSelf = self;
        _afterDropboxLinkedCompletion = ^(BOOL success) {
            [weakSelf innerCreate:desiredFilename parentReference:parentReference];
        };

        [[DBSession sharedSession] linkFromController:viewController];
    }
    else {
        [self innerCreate:desiredFilename parentReference:parentReference ];
    }
}

- (void)read:(SafeMetaData *)safeMetaData viewController:(UIViewController *)viewController completionHandler:(void (^)(NSData *data, NSError *error))completion {
    _pendingOperation = [[PendingDropboxOperation alloc] initForRead:viewController safe:safeMetaData completion:completion];

    if (![[DBSession sharedSession] isLinked]) {
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(isDropboxLinkedHandle2:) name:@"isDropboxLinked" object:nil];

        __weak typeof(self) weakSelf = self;
        _afterDropboxLinkedCompletion = ^(BOOL success) {
            [weakSelf innerLoad];
        };

        [[DBSession sharedSession] linkFromController:viewController];
    }
    else {
        [self innerLoad];
    }
}

- (void)update:(SafeMetaData *)safeMetaData data:(NSData *)data viewController:(UIViewController *)viewController completionHandler:(void (^)(NSError *error))completion {
    _pendingOperation = [[PendingDropboxOperation alloc] initForUpdate:viewController safe:safeMetaData data:data completion:completion];

    if (![[DBSession sharedSession] isLinked]) {
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(isDropboxLinkedHandle2:) name:@"isDropboxLinked" object:nil];

        __weak typeof(self) weakSelf = self;
        _afterDropboxLinkedCompletion = ^(BOOL success) {
            [weakSelf innerUpdate];
        };

        [[DBSession sharedSession] linkFromController:viewController];
    }
    else {
        [self innerUpdate];
    }
}

- (void)delete:(SafeMetaData *)safeMetaData completionHandler:(void (^)(NSError *))completion {
    // NOTIMPL
}

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)innerCreate:(NSString *)desiredFilename parentReference:(NSString *)parentReference {
    NSString *tempFile = [NSTemporaryDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"%.0f.%@", [NSDate timeIntervalSinceReferenceDate] * 1000.0, @"dat"]];

    [_pendingOperation.saveData writeToFile:tempFile atomically:YES];

    // TODO: Check for collision
    //[self.restClient loadMetadata:[NSString pathWithComponents:@[folder, fileName]]];

    _restClient = [[DBRestClient alloc] initWithSession:[DBSession sharedSession]];
    _restClient.delegate = self;

    [_restClient uploadFile:desiredFilename toPath:parentReference withParentRev:nil fromPath:tempFile];
}

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)innerLoad {
    _restClient = [[DBRestClient alloc] initWithSession:[DBSession sharedSession]];
    _restClient.delegate = self;

    NSString *tempFile = [NSTemporaryDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"%.0f.%@", [NSDate timeIntervalSinceReferenceDate] * 1000.0, @"dat"]];

    [_restClient loadFile:_pendingOperation.safeMetaData.fileIdentifier intoPath:tempFile];
}

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)innerUpdate {
    _restClient = [[DBRestClient alloc] initWithSession:[DBSession sharedSession]];
    _restClient.delegate = self;

    [_restClient loadMetadata:_pendingOperation.safeMetaData.fileIdentifier];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)restClient:(DBRestClient *)client loadedFile:(NSString *)localPath
       contentType:(NSString *)contentType metadata:(DBMetadata *)metadata {
    NSData *data = [[NSFileManager defaultManager] contentsAtPath:localPath];

    // Delete the temporary file...

    NSError *error;

    [[NSFileManager defaultManager] removeItemAtPath:localPath error:&error];

    _pendingOperation.readCompletion(data, nil);
    _pendingOperation = nil;
}

- (void)restClient:(DBRestClient *)client loadFileFailedWithError:(NSError *)error {
    NSLog(@"%@", error);

    _pendingOperation.readCompletion(nil, error);
    _pendingOperation = nil;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)restClient:(DBRestClient *)client loadedMetadata:(DBMetadata *)metadata {
    //NSLog(@"Got file metadata successfully");

    NSString *tempFile = [NSTemporaryDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"%.0f.%@", [NSDate timeIntervalSinceReferenceDate] * 1000.0, @"dat"]];

    if ([_pendingOperation.saveData writeToFile:tempFile atomically:YES]) {
        NSString *path = [metadata.path stringByDeletingLastPathComponent];

        [_restClient uploadFile:metadata.filename toPath:path withParentRev:metadata.rev fromPath:tempFile];
    }
    else {
        NSLog(@"Dropbox: Error saving at loadMetadata stage");

        NSError *error = [Utils createNSError:@"Dropbox: Error saving at loadMetadata stage" errorCode:-1];

        _pendingOperation.updateCompletion(error);
        _pendingOperation = nil;
    }
}

- (void)restClient:(DBRestClient *)client loadMetadataFailedWithError:(NSError *)error {
    NSLog(@"Error loading metadata: %@", error);

    _pendingOperation.updateCompletion(error);
    _pendingOperation = nil;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)restClient:(DBRestClient *)client uploadedFile:(NSString *)destPath
              from:(NSString *)srcPath metadata:(DBMetadata *)metadata {
    // NSLog(@"Dropbox upload succeeded...");

    NSError *error;

    [[NSFileManager defaultManager] removeItemAtPath:srcPath error:&error];

    if (_pendingOperation.updateCompletion != nil) {
        _pendingOperation.updateCompletion(nil);
    }
    else {
        _pendingOperation.createCompletion(metadata.filename, metadata.path, nil);
    }

    _pendingOperation = nil;
}

- (void)restClient:(DBRestClient *)client uploadFileFailedWithError:(NSError *)error {
    NSLog(@"Dropbox upload failed with error: %@", error);

    if (_pendingOperation.updateCompletion != nil) {
        _pendingOperation.updateCompletion(error);
    }
    else {
        _pendingOperation.createCompletion(nil, nil, error);
    }

    _pendingOperation = nil;
}

@end
