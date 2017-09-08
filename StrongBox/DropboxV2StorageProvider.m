//
//  DropboxV2StorageProvider.m
//  StrongBox
//
//  Created by Mark on 26/05/2017.
//  Copyright © 2017 Mark McGuill. All rights reserved.
//

#import "DropboxV2StorageProvider.h"
#import <ObjectiveDropboxOfficial/ObjectiveDropboxOfficial.h>
#import "Utils.h"
#import <SVProgressHUD/SVProgressHUD.h>

@implementation DropboxV2StorageProvider

+ (instancetype)sharedInstance {
    static DropboxV2StorageProvider *sharedInstance = nil;
    static dispatch_once_t onceToken;
    
    dispatch_once(&onceToken, ^{
        sharedInstance = [[DropboxV2StorageProvider alloc] init];
    });
    return sharedInstance;
}

- (instancetype)init {
    if (self = [super init]) {
        _displayName = @"Dropbox";
        _icon = @"dropbox-blue-32x32-nologo";
        _storageId = kDropbox;
        _cloudBased = YES;
        _providesIcons = NO;
        _browsable = YES;

        return self;
    }
    else {
        return nil;
    }
}

- (void)    create:(NSString *)nickName
              data:(NSData *)data
      parentFolder:(NSObject *)parentFolder
    viewController:(UIViewController *)viewController
        completion:(void (^)(SafeMetaData *metadata, NSError *error))completion {
    [SVProgressHUD show];

    NSString *desiredFilename = [NSString stringWithFormat:@"%@-strongbox.dat", nickName];

    NSString *parentFolderPath = parentFolder ? ((DBFILESFolderMetadata *)parentFolder).pathLower : @"/";

    NSString *path = [NSString pathWithComponents:
                      @[parentFolderPath, desiredFilename]];

    [self createOrUpdate:path
                    data:data
              completion:^(NSError *error) {
                  dispatch_async(dispatch_get_main_queue(), ^{
                  [SVProgressHUD popActivity];
                  });

                  if (error == nil) {
                  SafeMetaData *metadata = [[SafeMetaData alloc] initWithNickName:nickName
                                                            storageProvider:self.storageId
                                                        offlineCacheEnabled:YES];
                  metadata.fileName = desiredFilename;
                  metadata.fileIdentifier = parentFolderPath;
                  completion(metadata, error);
                  }
                  else {
                  completion(nil, error);
                  }
              }];
}

- (void)      read:(SafeMetaData *)safeMetaData
    viewController:(UIViewController *)viewController
        completion:(void (^)(NSData *data, NSError *error))completion {
    NSString *path = [NSString pathWithComponents:
                      @[safeMetaData.fileIdentifier, safeMetaData.fileName]];

    [self performTaskWithAuthorizationIfNecessary:viewController
                                             task:^(NSError *error) {
                                                 if (error) {
                                                     completion(nil, error);
                                                 }
                                                 else {
                                                     [self readFileWithPath:path completion:completion];
                                                 }
                                             }];
}

- (void)readWithProviderData:(NSObject *)providerData
              viewController:(UIViewController *)viewController
                  completion:(void (^)(NSData *data, NSError *error))completion {
    DBFILESFileMetadata *file = (DBFILESFileMetadata *)providerData;

    [self readFileWithPath:file.pathLower completion:completion];
}

- (void)readFileWithPath:(NSString *)path completion:(void (^)(NSData *data, NSError *error))completion {
    [SVProgressHUD show];

    DBUserClient *client = DBClientsManager.authorizedClient;
    [[[client.filesRoutes downloadData:path]
      setResponseBlock:^(DBFILESFileMetadata *result, DBFILESDownloadError *routeError, DBRequestError *networkError,
                         NSData *fileContents)
    {
        dispatch_async(dispatch_get_main_queue(), ^{
            [SVProgressHUD popActivity];
        });

        if (result) {
            completion(fileContents, nil);
        }
        else {
            NSString *message = [[NSString alloc] initWithFormat:@"%@\n%@\n", routeError, networkError];
            completion(nil, [Utils createNSError:message
                                       errorCode:-1]);
        }
    }]
     setProgressBlock:^(int64_t bytesDownloaded, int64_t totalBytesDownloaded, int64_t totalBytesExpectedToDownload) {
         //NSLog(@"Dropbox Read Progress: %lld\n%lld\n%lld\n", bytesDownloaded, totalBytesDownloaded, totalBytesExpectedToDownload);
     }];
}

- (void)update:(SafeMetaData *)safeMetaData
          data:(NSData *)data
    completion:(void (^)(NSError *error))completion {
    NSString *path = [NSString pathWithComponents:
                      @[safeMetaData.fileIdentifier, safeMetaData.fileName]];

    [self createOrUpdate:path data:data completion:completion];
}

- (void)createOrUpdate:(NSString *)path
                  data:(NSData *)data
            completion:(void (^)(NSError *error))completion {
    [SVProgressHUD show];

    DBUserClient *client = DBClientsManager.authorizedClient;


    [[[client.filesRoutes uploadData:path
                                mode:[[DBFILESWriteMode alloc] initWithOverwrite]
                          autorename:@(NO)
                      clientModified:nil
                                mute:@(NO)
                           inputData:data]
      setResponseBlock:^(DBFILESFileMetadata *result, DBFILESUploadError *routeError, DBRequestError *networkError) {
          dispatch_async(dispatch_get_main_queue(), ^{
            [SVProgressHUD popActivity];
          });

          if (result) {
            completion(nil);
          }
          else {
            NSLog(@"%@\n%@\n", routeError, networkError);
            NSString *message = [[NSString alloc] initWithFormat:@"%@\n%@", routeError, networkError];
            completion([Utils createNSError:message
                                  errorCode:-1]);
          }
      }] setProgressBlock:^(int64_t bytesUploaded, int64_t totalBytesUploaded, int64_t totalBytesExpectedToUploaded) {
          //NSLog(@"Dropbox Progress: %lld\n%lld\n%lld\n", bytesUploaded, totalBytesUploaded, totalBytesExpectedToUploaded);
         }];
}

- (void)      list:(NSObject *)parentFolder
    viewController:(UIViewController *)viewController
        completion:(void (^)(NSArray<StorageBrowserItem *> *items, NSError *error))completion {
    [self performTaskWithAuthorizationIfNecessary:viewController
                                             task:^(NSError *error) {
                                                 if (error) {
                                                 completion(nil, error);
                                                 }
                                                 else {
                                                 [self listFolder:parentFolder
                                                 completion:completion];
                                                 }
                                             }];
}

- (void)performTaskWithAuthorizationIfNecessary:(UIViewController *)viewController
                                           task:(void (^)(NSError *error))task {
    if (!DBClientsManager.authorizedClient) {
        NSNotificationCenter * __weak center = [NSNotificationCenter defaultCenter];
        id __block token = [center addObserverForName:@"isDropboxLinked"
                                                          object:nil
                                                           queue:nil
                                                      usingBlock:^(NSNotification *_Nonnull note)
        {
            [center removeObserver:token];
            
            DBOAuthResult *authResult = (DBOAuthResult *)note.object;

            if (DBClientsManager.authorizedClient) {
                NSLog(@"Linked");
                task(nil);
            }
            else {
                NSLog(@"Not Linked");
                NSLog(@"Error: %@", authResult);
                task([Utils createNSError:@"Could not create link to Dropbox."
                                errorCode:-1]);
            }
        }];

        // Sigh... required to ignore warning about unused variable... which is actually used. Bad design of addObserverForName
        (void)token;
        
        [DBClientsManager authorizeFromController:[UIApplication sharedApplication]
                                       controller:viewController
                                          openURL:^(NSURL *url) { [[UIApplication sharedApplication] openURL:url]; }];
    }
    else {
        task(nil);
    }
}

- (void)listFolder:(NSObject *)parentFolder
        completion:(void (^)(NSArray<StorageBrowserItem *> *items, NSError *error))completion {
    [SVProgressHUD show];

    NSMutableArray<StorageBrowserItem *> *items = [[NSMutableArray alloc] init];
    DBFILESMetadata *parent = (DBFILESMetadata *)parentFolder;

    [[DBClientsManager.authorizedClient.filesRoutes listFolder:parent ? parent.
      pathLower : @""]
     setResponseBlock:^(DBFILESListFolderResult *_Nullable response, DBFILESListFolderError *_Nullable routeError,
                        DBRequestError *_Nullable networkError) {
         if (response) {
            NSArray<DBFILESMetadata *> *entries = response.entries;
            NSString *cursor = response.cursor;
            BOOL hasMore = (response.hasMore).boolValue;

            [items addObjectsFromArray:[self mapToBrowserItems:entries]];

            if (hasMore) {
                [self listFolderContinue:cursor
                                   items:items
                              completion:completion];
            }
            else {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [SVProgressHUD popActivity];
                });

                completion(items, nil);
            }
         }
         else {
            NSString *message = [[NSString alloc] initWithFormat:@"%@\n%@", routeError, networkError];

            dispatch_async(dispatch_get_main_queue(), ^{
                [SVProgressHUD popActivity];
            });

            completion(nil, [Utils createNSError:message
                                       errorCode:-1]);
         }
     }];
}

- (void)listFolderContinue:(NSString *)cursor
                     items:(NSMutableArray<StorageBrowserItem *> *)items
                completion:(void (^)(NSArray<StorageBrowserItem *> *items, NSError *error))completion {
    DBUserClient *client = DBClientsManager.authorizedClient;

    [[client.filesRoutes listFolderContinue:cursor]
     setResponseBlock:^(DBFILESListFolderResult *response, DBFILESListFolderContinueError *routeError,
                        DBRequestError *networkError) {
         if (response) {
            NSArray<DBFILESMetadata *> *entries = response.entries;
            NSString *cursor = response.cursor;
            BOOL hasMore = (response.hasMore).boolValue;

            [items addObjectsFromArray:[self mapToBrowserItems:entries]];

            if (hasMore) {
                [self listFolderContinue:cursor
                                   items:items
                              completion:completion];
            }
            else {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [SVProgressHUD popActivity];
                });

                completion(items, nil);
            }
         }
         else {
            NSString *message = [[NSString alloc] initWithFormat:@"%@\n%@\n", routeError, networkError];
            dispatch_async(dispatch_get_main_queue(), ^{
                [SVProgressHUD popActivity];
            });

            completion(nil, [Utils createNSError:message
                                       errorCode:-1]);
         }
     }];
}

- (NSArray *)mapToBrowserItems:(NSArray<DBFILESMetadata *> *)entries {
    NSMutableArray<StorageBrowserItem *> *ret = [[NSMutableArray alloc] init];

    for (DBFILESMetadata *entry in entries) {
        StorageBrowserItem *item = [[StorageBrowserItem alloc] init];
        item.providerData = entry;
        item.name = entry.name;

        if ([entry isKindOfClass:[DBFILESFileMetadata class]]) {
            item.folder = false;
        }
        else if ([entry isKindOfClass:[DBFILESFolderMetadata class]])
        {
            item.folder = true;
        }

        [ret addObject:item];
    }

    return ret;
}

- (SafeMetaData *)getSafeMetaData:(NSString *)nickName providerData:(NSObject *)providerData {
    SafeMetaData *safe = [[SafeMetaData alloc] initWithNickName:nickName
                                                storageProvider:self.storageId
                                            offlineCacheEnabled:YES];

    DBFILESFileMetadata *file = (DBFILESFileMetadata *)providerData;

    safe.fileName = file.name;

    NSString *parent = (file.pathLower).stringByDeletingLastPathComponent;

    safe.fileIdentifier = parent;

    return safe;
}

- (void)loadIcon:(NSObject *)providerData viewController:(UIViewController *)viewController
      completion:(void (^)(UIImage *image))completionHandler {
    // NOTSUPPORTED
}

@end
