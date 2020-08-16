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
#import "SVProgressHUD.h"
#import "Constants.h"
#import "NSDate+Extensions.h"

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
        _storageId = kDropbox;
        _providesIcons = NO;
        _browsableNew = YES;
        _browsableExisting = YES;
        _rootFolderOnly = NO;
        _immediatelyOfferCacheIfOffline = YES; // Dropbox has a long delay if offline and unreachable - offer immediately if offline detected
        
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
        completion:(void (^)(SafeMetaData *metadata, const NSError *error))completion {
    [SVProgressHUD show];

    NSString *desiredFilename = [NSString stringWithFormat:@"%@.%@", nickName, extension];

    NSString *parentFolderPath = parentFolder ? ((DBFILESFolderMetadata *)parentFolder).pathLower : @"/";

    NSString *path = [NSString pathWithComponents:
                      @[parentFolderPath, desiredFilename]];

    [self createOrUpdate:viewController
                    path:path
                    data:data
              completion:^(StorageProviderUpdateResult result, NSDate * _Nullable newRemoteModDate, const NSError * _Nullable error) {
      dispatch_async(dispatch_get_main_queue(), ^{
          [SVProgressHUD dismiss];
      });

      if (error == nil) {
          SafeMetaData *metadata = [[SafeMetaData alloc] initWithNickName:nickName
                                                          storageProvider:self.storageId
                                                                 fileName:desiredFilename
                                                           fileIdentifier:parentFolderPath];

          completion(metadata, error);
      }
      else {
          completion(nil, error);
      }
    }];
}

- (void)pullDatabase:(SafeMetaData *)safeMetaData
    interactiveVC:(UIViewController *)viewController
           options:(StorageProviderReadOptions *)options
        completion:(StorageProviderReadCompletionBlock)completion {
    NSString *path = [NSString pathWithComponents:@[safeMetaData.fileIdentifier, safeMetaData.fileName]];
    
    [self performTaskWithAuthorizationIfNecessary:viewController
                                             task:^(BOOL userCancelled, BOOL userInteractionRequired, NSError *error) {
        if (error) {
            completion(kReadResultError, nil, nil, error);
        }
        else if (userInteractionRequired) {
            completion(kReadResultBackgroundReadButUserInteractionRequired, nil, nil, nil);
        }
        else {
            [self readFileWithPath:path viewController:viewController options:options completion:completion];
        }
    }];
}

- (void)readWithProviderData:(NSObject *)providerData viewController:(UIViewController *)viewController options:(StorageProviderReadOptions *)options completion:(StorageProviderReadCompletionBlock)completionHandler {
    DBFILESFileMetadata *file = (DBFILESFileMetadata *)providerData;
    [self readFileWithPath:file.pathLower viewController:viewController options:options completion:completionHandler];
}

- (void)readFileWithPath:(NSString *)path viewController:(UIViewController*)viewController options:(StorageProviderReadOptions *)options completion:(StorageProviderReadCompletionBlock)completion {
    if (viewController) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [SVProgressHUD showWithStatus:NSLocalizedString(@"storage_provider_status_reading", @"A storage provider is in the process of reading. This is the status displayed on the progress dialog. In english:  Reading...")];
        });
    }

    DBUserClient *client = DBClientsManager.authorizedClient;
    
    // Check Metadata:
    
    [[client.filesRoutes getMetadata:path] setResponseBlock:^(DBFILESMetadata * _Nullable result, DBFILESGetMetadataError * _Nullable routeError, DBRequestError * _Nullable networkError) {
        if (result) {
            DBFILESFileMetadata* metadata = (DBFILESFileMetadata*)result;
            
            NSLog(@"Dropbox Date Modified: [%@]", metadata.serverModified);

            if (options && options.onlyIfModifiedDifferentFrom) {
                if ([metadata.serverModified isEqualToDateWithinEpsilon:options.onlyIfModifiedDifferentFrom]) {
                    if (viewController) {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [SVProgressHUD dismiss];
                        });
                    }
                    
                    completion(kReadResultModifiedIsSameAsLocal, nil, nil, nil);
                    return;
                }
            }
            
            [[[client.filesRoutes downloadData:path]
              setResponseBlock:^(DBFILESFileMetadata *result, DBFILESDownloadError *routeError, DBRequestError *networkError,
                                 NSData *fileContents) {
                if (viewController) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [SVProgressHUD dismiss];
                    });
                }

                if (result) {
                    completion(kReadResultSuccess, fileContents, result.serverModified, nil);
                }
                else {
                    NSString *message = [[NSString alloc] initWithFormat:@"%@\n%@\n", routeError, networkError];
                    completion(kReadResultError, nil, nil, [Utils createNSError:message errorCode:-1]);
                }
            }]
             setProgressBlock:^(int64_t bytesDownloaded, int64_t totalBytesDownloaded, int64_t totalBytesExpectedToDownload) {
                 //NSLog(@"Dropbox Read Progress: %lld\n%lld\n%lld\n", bytesDownloaded, totalBytesDownloaded, totalBytesExpectedToDownload);
             }];
        }
        else {
            if (viewController) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [SVProgressHUD dismiss];
                });
            }

            NSString *message = [[NSString alloc] initWithFormat:@"%@\n%@\n", routeError, networkError];
            completion(kReadResultError, nil, nil, [Utils createNSError:message errorCode:-1]);
        }
    }];
}

- (void)pushDatabase:(SafeMetaData *)safeMetaData interactiveVC:(UIViewController *)viewController data:(NSData *)data isAutoFill:(BOOL)isAutoFill completion:(StorageProviderUpdateCompletionBlock)completion {
    NSString *path = [NSString pathWithComponents:@[safeMetaData.fileIdentifier, safeMetaData.fileName]];
    [self createOrUpdate:viewController path:path data:data completion:completion];
}

- (void)createOrUpdate:(UIViewController*)viewController path:(NSString *)path data:(NSData *)data completion:(StorageProviderUpdateCompletionBlock)completion {
    [SVProgressHUD showWithStatus:NSLocalizedString(@"storage_provider_status_syncing", @"Syncing...")];

    DBUserClient *client = DBClientsManager.authorizedClient;
    
    [[[client.filesRoutes uploadData:path
                                mode:[[DBFILESWriteMode alloc] initWithOverwrite]
                          autorename:@(NO)
                      clientModified:nil
                                mute:@(NO)
                      propertyGroups:nil
                      strictConflict:@(NO)
                           inputData:data]
      setResponseBlock:^(DBFILESFileMetadata *result, DBFILESUploadError *routeError, DBRequestError *networkError) {
        if (viewController) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [SVProgressHUD dismiss];
            });
        }

        if (result) {
            completion(kUpdateResultSuccess, result.serverModified, nil);
        }
        else {
            NSLog(@"%@\n%@\n", routeError, networkError);
            NSString *message = [[NSString alloc] initWithFormat:@"%@\n%@", routeError, networkError];
            completion(kUpdateResultError, nil, [Utils createNSError:message errorCode:-1]);
        }
    }] setProgressBlock:^(int64_t bytesUploaded, int64_t totalBytesUploaded, int64_t totalBytesExpectedToUploaded) {
          //NSLog(@"Dropbox Progress: %lld\n%lld\n%lld\n", bytesUploaded, totalBytesUploaded, totalBytesExpectedToUploaded);
    }];
}

- (void)      list:(NSObject *)parentFolder
    viewController:(UIViewController *)viewController
        completion:(void (^)(BOOL, NSArray<StorageBrowserItem *> *, const NSError *))completion {
    [self performTaskWithAuthorizationIfNecessary:viewController task:^(BOOL userCancelled, BOOL userInteractionRequired, NSError *error) {
        if (error) {
            completion(userCancelled, nil, error);
        }
        else {
            [self listFolder:parentFolder completion:completion];
        }
    }];
}

- (void)performTaskWithAuthorizationIfNecessary:(UIViewController *)viewController
                                           task:(void (^)(BOOL userCancelled, BOOL userInteractionRequired, NSError *error))task {
    if (!DBClientsManager.authorizedClient) {
        if (!viewController) {
            task(NO, YES, nil);
            return;
        }
        
#ifndef IS_APP_EXTENSION
        NSNotificationCenter * __weak center = [NSNotificationCenter defaultCenter];
        id __block token = [center addObserverForName:@"isDropboxLinked" object:nil queue:nil usingBlock:^(NSNotification *_Nonnull note) {
            [center removeObserver:token];
  
            if (DBClientsManager.authorizedClient) {
                NSLog(@"Linked");
                task(NO, NO, nil);
            }
            else {
                NSLog(@"Not Linked");
                DBOAuthResult *authResult = (DBOAuthResult *)note.object;
                NSLog(@"Error: %@", authResult);
                task(authResult.tag == DBAuthCancel, NO, [Utils createNSError:[NSString stringWithFormat:@"Could not create link to Dropbox: [%@]", authResult] errorCode:-1]);
            }
        }];


        // Sigh... required to ignore warning about unused variable... which is actually used. Bad design of addObserverForName
        (void)token;
        
        // Needs to be done on main queue...
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [SVProgressHUD dismiss]; // Hide any progress indicator
            
            [DBClientsManager authorizeFromController:[UIApplication sharedApplication]
                                           controller:viewController
                                              openURL:^(NSURL *url) {
                [UIApplication.sharedApplication openURL:url options:@{ } completionHandler:nil];
            }];
        });
        
#else
        NSLog(@"Dropbox not fully available with App Extension. Displaying Alert.");
        
        NSError* error = [Utils createNSError:@"Could not create link to Dropbox. Dropbox is not fully available in App Extension." errorCode:-1];
        
        task(NO, NO, error);
#endif
    }
    else {
        task(NO, NO, nil);
    }
}

- (void)listFolder:(NSObject *)parentFolder
        completion:(void (^)(BOOL userCancelled, NSArray<StorageBrowserItem *> *items, NSError *error))completion {
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
                    [SVProgressHUD dismiss];
                });

                completion(NO, items, nil);
            }
         }
         else {
            NSString *message = [[NSString alloc] initWithFormat:@"%@\n%@", routeError, networkError];

            dispatch_async(dispatch_get_main_queue(), ^{
                [SVProgressHUD dismiss];
            });

            completion(NO, nil, [Utils createNSError:message errorCode:-1]);
         }
     }];
}

- (void)listFolderContinue:(NSString *)cursor
                     items:(NSMutableArray<StorageBrowserItem *> *)items
                completion:(void (^)(BOOL userCancelled, NSArray<StorageBrowserItem *> *items, NSError *error))completion {
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
                    [SVProgressHUD dismiss];
                });

                completion(NO, items, nil);
            }
         }
         else {
            NSString *message = [[NSString alloc] initWithFormat:@"%@\n%@\n", routeError, networkError];
            dispatch_async(dispatch_get_main_queue(), ^{
                [SVProgressHUD dismiss];
            });

            completion(NO, nil, [Utils createNSError:message errorCode:-1]);
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
    DBFILESFileMetadata *file = (DBFILESFileMetadata *)providerData;
    NSString *parent = (file.pathLower).stringByDeletingLastPathComponent;

    return [[SafeMetaData alloc] initWithNickName:nickName
                                  storageProvider:self.storageId
                                         fileName:file.name
                                   fileIdentifier:parent];
}

- (void)loadIcon:(NSObject *)providerData viewController:(UIViewController *)viewController
      completion:(void (^)(UIImage *image))completionHandler {
    // NOTSUPPORTED
}

- (void)delete:(SafeMetaData *)safeMetaData completion:(void (^)(const NSError *))completion {
    // NOTIMPL
}

@end
