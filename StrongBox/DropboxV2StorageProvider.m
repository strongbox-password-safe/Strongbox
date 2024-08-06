//
//  DropboxV2StorageProvider.m
//  StrongBox
//
//  Created by Mark on 26/05/2017.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import "DropboxV2StorageProvider.h"
#import "Utils.h"
#import "Constants.h"
#import "NSDate+Extensions.h"
#import <ObjectiveDropboxOfficial/ObjectiveDropboxOfficial.h>
#import "real-secrets.h"

#if TARGET_OS_IPHONE

#import "SVProgressHUD.h"
#import "AppPreferences.h"

#else

#import "macOSSpinnerUI.h"
#import "MacUrlSchemes.h"

#endif

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
        _defaultForImmediatelyOfferOfflineCache = YES; 
        _supportsConcurrentRequests = NO; 
        _privacyOptInRequired = YES;
        
        return self;
    }
    else {
        return nil;
    }
}



- (BOOL)isAuthorized {
    return DBClientsManager.authorizedClient != nil;
}

- (void)signOut {
    [DBClientsManager unlinkAndResetClients];
}

- (void)initialize:(BOOL)useIsolatedDropbox {
#if TARGET_OS_IPHONE
    if ( useIsolatedDropbox ) {
        [DBClientsManager setupWithAppKey:DROPBOX_APP_ISOLATED_KEY];
    }
    else {
        [DBClientsManager setupWithAppKey:DROPBOX_APP_KEY];
    }
#else
    if ( useIsolatedDropbox ) {
        [DBClientsManager setupWithAppKeyDesktop:DROPBOX_APP_ISOLATED_KEY];
    }
    else {
        [DBClientsManager setupWithAppKeyDesktop:DROPBOX_APP_KEY];
    }
#endif
}

- (void)dismissProgressSpinner {
    dispatch_async(dispatch_get_main_queue(), ^{
#if TARGET_OS_IPHONE
        [SVProgressHUD dismiss];
#else
        [macOSSpinnerUI.sharedInstance dismiss];
#endif
    });
}

- (void)showProgressSpinner:(NSString*)message viewController:(VIEW_CONTROLLER_PTR)viewController {
    dispatch_async(dispatch_get_main_queue(), ^{
#if TARGET_OS_IPHONE
        [SVProgressHUD showWithStatus:message];
#else
        [macOSSpinnerUI.sharedInstance show:message viewController:viewController];
#endif
    });
}

- (void)getModDate:(nonnull METADATA_PTR)safeMetaData completion:(nonnull StorageProviderGetModDateCompletionBlock)completion {
    NSString* path = [self getPathFromDatabaseMetadata:safeMetaData];

    [self performTaskWithAuthorizationIfNecessary:nil task:^(BOOL userCancelled, BOOL userInteractionRequired, NSError *error) {
        if (error) {
            completion(YES, nil, error);
        }
        else if (userInteractionRequired) {
            completion(YES, nil, [Utils createNSError:@"User Interaction Required from getModDate" errorCode:346]);
        }
        else {
            DBUserClient *client = DBClientsManager.authorizedClient;
            
            
            
            [[client.filesRoutes getMetadata:path] setResponseBlock:^(DBFILESMetadata * _Nullable result, DBFILESGetMetadataError * _Nullable routeError, DBRequestError * _Nullable networkError) {
                if (result) {
                    DBFILESFileMetadata* metadata = (DBFILESFileMetadata*)result;
                    

                    
                    completion(YES, metadata.serverModified, nil);
                }
                else {
                    completion(YES, nil, [Utils createNSError:@"Error getModDate" errorCode:347]);
                }
            }];
        }
    }];

}

- (void)create:(NSString *)nickName
      fileName:(NSString *)fileName
          data:(NSData *)data
  parentFolder:(NSObject *)parentFolder
viewController:(VIEW_CONTROLLER_PTR)viewController
    completion:(void (^)(METADATA_PTR _Nullable, const NSError * _Nullable))completion {
    [self showProgressSpinner:@"" viewController:viewController];

    NSString *parentFolderPath = parentFolder ? ((DBFILESFolderMetadata *)parentFolder).pathLower : @"/";

    NSString *path = [NSString pathWithComponents:
                      @[parentFolderPath, fileName]];

    [self createOrUpdate:viewController
                    path:path
                    data:data
              completion:^(StorageProviderUpdateResult result, NSDate * _Nullable newRemoteModDate, const NSError * _Nullable error) {
        [self dismissProgressSpinner];

        if (error == nil) {
            METADATA_PTR metadata = [self getDatabaseMetadata:fileName parentPath:parentFolderPath nickName:nickName];
            
            completion(metadata, nil);
        }
        else {
            completion(nil, error);
        }
    }];
}

- (void)pullDatabase:(METADATA_PTR )safeMetaData
    interactiveVC:(VIEW_CONTROLLER_PTR )viewController
           options:(StorageProviderReadOptions *)options
        completion:(StorageProviderReadCompletionBlock)completion {
    NSString* path = [self getPathFromDatabaseMetadata:safeMetaData];

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

- (void)readWithProviderData:(NSObject *)providerData
              viewController:(VIEW_CONTROLLER_PTR )viewController
                     options:(StorageProviderReadOptions *)options
                  completion:(StorageProviderReadCompletionBlock)completionHandler {
    DBFILESFileMetadata *file = (DBFILESFileMetadata *)providerData;
    [self readFileWithPath:file.pathLower viewController:viewController options:options completion:completionHandler];
}

- (void)readFileWithPath:(NSString *)path
          viewController:(VIEW_CONTROLLER_PTR )viewController
                 options:(StorageProviderReadOptions *)options
              completion:(StorageProviderReadCompletionBlock)completion {
    if (viewController) {
        [self showProgressSpinner:NSLocalizedString(@"storage_provider_status_reading", @"A storage provider is in the process of reading. This is the status displayed on the progress dialog. In english:  Reading...")
                   viewController:viewController];
    }

    DBUserClient *client = DBClientsManager.authorizedClient;
    
    
    
    [[client.filesRoutes getMetadata:path] setResponseBlock:^(DBFILESMetadata * _Nullable result, DBFILESGetMetadataError * _Nullable routeError, DBRequestError * _Nullable networkError) {
        if (result) {
            DBFILESFileMetadata* metadata = (DBFILESFileMetadata*)result;
            


            if (options && options.onlyIfModifiedDifferentFrom) {
                if ([metadata.serverModified isEqualToDateWithinEpsilon:options.onlyIfModifiedDifferentFrom]) {
                    if (viewController) {
                        [self dismissProgressSpinner];
                    }
                    
                    completion(kReadResultModifiedIsSameAsLocal, nil, nil, nil);
                    return;
                }
            }
            
            [[[client.filesRoutes downloadData:path]
              setResponseBlock:^(DBFILESFileMetadata *result, DBFILESDownloadError *routeError, DBRequestError *networkError,
                                 NSData *fileContents) {
                if (viewController) {
                    [self dismissProgressSpinner];
                }

                if (result) {
                    completion(kReadResultSuccess, fileContents, result.serverModified, nil);
                }
                else {
                    NSString *message = [self handleRequestError:networkError];
                    if ( !message) {
                        message = [[NSString alloc] initWithFormat:@"%@\n%@", routeError, networkError];
                    }

                    completion(kReadResultError, nil, nil, [Utils createNSError:message errorCode:-1]);
                }
            }]
             setProgressBlock:^(int64_t bytesDownloaded, int64_t totalBytesDownloaded, int64_t totalBytesExpectedToDownload) {
                 
             }];
        }
        else {
            if (viewController) {
                [self dismissProgressSpinner];
            }
            
            if ( routeError && routeError.tag == DBFILESGetMetadataErrorPath && routeError.isPath ) {
                slog(@"🔴 Dropbox - Could not find file at path [%@]", path);
                completion(kReadResultError, nil, nil, [Utils createNSError:[NSString stringWithFormat:@"Could not find file at %@", path] errorCode:-1]);
            }
            else
            {
                NSString *message = [[NSString alloc] initWithFormat:@"🔴 %@\n%@\n", routeError, networkError];
                completion(kReadResultError, nil, nil, [Utils createNSError:message errorCode:-1]);
            }
        }
    }];
}

- (void)pushDatabase:(METADATA_PTR )safeMetaData interactiveVC:(VIEW_CONTROLLER_PTR )viewController data:(NSData *)data completion:(StorageProviderUpdateCompletionBlock)completion {
    NSString* path = [self getPathFromDatabaseMetadata:safeMetaData];
    
    [self createOrUpdate:viewController path:path data:data completion:completion];
}

- (void)createOrUpdate:(VIEW_CONTROLLER_PTR )viewController path:(NSString *)path data:(NSData *)data completion:(StorageProviderUpdateCompletionBlock)completion {
    if (viewController) {
        [self showProgressSpinner:NSLocalizedString(@"storage_provider_status_syncing", @"Syncing...") viewController:viewController];
    }
    
    DBUserClient *client = DBClientsManager.authorizedClient;
    
    DBUploadTask* request = [client.filesRoutes uploadData:path
                                           mode:[[DBFILESWriteMode alloc] initWithOverwrite]
                                     autorename:@(NO)
                                 clientModified:nil
                                           mute:@(NO)
                                 propertyGroups:nil
                                 strictConflict:@(NO)
                                    contentHash:nil
                                      inputData:data];
    
    [[request setResponseBlock:^(DBFILESFileMetadata *result, DBFILESUploadError *routeError, DBRequestError *networkError) {
        if (viewController) {
            [self dismissProgressSpinner];
        }

        if (result) {
            completion(kUpdateResultSuccess, result.serverModified, nil);
        }
        else {
            if ( routeError.isPath ) {
                DBFILESUploadWriteFailed* writeFailed = routeError.path;
                if ( writeFailed && writeFailed.reason ) {
                    if ( writeFailed.reason.isInsufficientSpace ) {
                        completion(kUpdateResultError, nil, [Utils createNSError:@"You have run out of space on Dropbox." errorCode:-1]);
                        return;
                    }
                }
            }
            
            NSString *message = [self handleRequestError:networkError];
            if ( !message) {
                message = [[NSString alloc] initWithFormat:@"%@\n%@", routeError, networkError];
            }

            completion(kUpdateResultError, nil, [Utils createNSError:message errorCode:-1]);
        }
    }] setProgressBlock:^(int64_t bytesUploaded, int64_t totalBytesUploaded, int64_t totalBytesExpectedToUploaded) {
          
    }];
}

- (void)      list:(NSObject *)parentFolder
    viewController:(VIEW_CONTROLLER_PTR )viewController
        completion:(void (^)(BOOL, NSArray<StorageBrowserItem *> *, const NSError *))completion {
    [self performTaskWithAuthorizationIfNecessary:viewController
                                             task:^(BOOL userCancelled, BOOL userInteractionRequired, NSError *error) {
        if (error) {
            completion(userCancelled, nil, error);
        }
        else {
            [self listFolder:parentFolder viewController:viewController completion:completion];
        }
    }];
}

- (void)listFolder:(NSObject *)parentFolder
    viewController:(VIEW_CONTROLLER_PTR )viewController
        completion:(void (^)(BOOL userCancelled, NSArray<StorageBrowserItem *> *items, NSError *error))completion {
    [self showProgressSpinner:@"" viewController:viewController];

    NSMutableArray<StorageBrowserItem *> *items = [[NSMutableArray alloc] init];
    DBFILESMetadata *parent = (DBFILESMetadata *)parentFolder;
    
    [[DBClientsManager.authorizedClient.filesRoutes listFolder:parent ? parent.pathLower : @""] setResponseBlock:^(DBFILESListFolderResult *_Nullable response, DBFILESListFolderError *_Nullable routeError,
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
                [self dismissProgressSpinner];
                completion(NO, items, nil);
            }
         }
         else {
            NSString *message = [self handleRequestError:networkError];
            if ( !message) {
                message = [[NSString alloc] initWithFormat:@"%@\n%@", routeError, networkError];
            }

            [self dismissProgressSpinner];
             
            completion(NO, nil, [Utils createNSError:message errorCode:-1]);
         }
     }];
}

- (NSString*)handleRequestError:(DBRequestError*)networkError {
    if ( networkError && networkError.structuredAuthError ) {
        if ( networkError.structuredAuthError.tag == DBAUTHAuthErrorExpiredAccessToken ||
             networkError.structuredAuthError.tag == DBAUTHAuthErrorOther ||
             networkError.structuredAuthError.tag == DBAUTHAuthErrorInvalidAccessToken ) {
            [DBClientsManager unlinkAndResetClients];
        }
        
        return [NSString stringWithFormat:@"%@", networkError];
    }
    
    return nil;
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
                [self dismissProgressSpinner];
                
                completion(NO, items, nil);
            }
         }
         else {
             NSString *message = [self handleRequestError:networkError];
             if ( !message) {
                 message = [[NSString alloc] initWithFormat:@"%@\n%@", routeError, networkError];
             }

             [self dismissProgressSpinner];
             
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

        item.identifier = entry.pathDisplay;
        
        [ret addObject:item];
    }

    return ret;
}

- (METADATA_PTR )getDatabasePreferences:(NSString *)nickName providerData:(NSObject *)providerData {
    DBFILESFileMetadata *file = (DBFILESFileMetadata *)providerData;
    NSString *parent = (file.pathLower).stringByDeletingLastPathComponent;

    return [self getDatabaseMetadata:file.name parentPath:parent nickName:nickName];
}

- (METADATA_PTR)getDatabaseMetadata:(NSString*)filename
                         parentPath:(NSString*)parentPath
                           nickName:(NSString*)nickName {
#if TARGET_OS_IPHONE
            METADATA_PTR metadata = [DatabasePreferences templateDummyWithNickName:nickName
                                                                   storageProvider:self.storageId
                                                                          fileName:filename
                                                                    fileIdentifier:parentPath];
#else
    NSURLComponents* components = [[NSURLComponents alloc] init];
    components.scheme = kStrongboxDropboxUrlScheme;
    components.path = [NSString stringWithFormat:@"/host/%@", filename]; 
    

                
    METADATA_PTR metadata = [MacDatabasePreferences templateDummyWithNickName:nickName
                                                              storageProvider:self.storageId
                                                                      fileUrl:components.URL
                                                                  storageInfo:parentPath];


    components.queryItems = @[[NSURLQueryItem queryItemWithName:@"uuid" value:metadata.uuid]];
    metadata.fileUrl = components.URL;
    


#endif
    
    return metadata;
}

-(NSString*)getPathFromDatabaseMetadata:(METADATA_PTR )safeMetaData {
#if TARGET_OS_IPHONE
    NSString *path = [NSString pathWithComponents:@[safeMetaData.fileIdentifier, safeMetaData.fileName]];
#else
    NSString *path = [NSString pathWithComponents:@[safeMetaData.storageInfo, safeMetaData.fileUrl.lastPathComponent]];
#endif

    return path;
}

- (void)loadIcon:(NSObject *)providerData viewController:(VIEW_CONTROLLER_PTR )viewController
      completion:(void (^)(IMAGE_TYPE_PTR image))completionHandler {
    
}

- (void)delete:(METADATA_PTR )safeMetaData completion:(void (^)(const NSError *))completion {
    
}

- (void)performTaskWithAuthorizationIfNecessary:(VIEW_CONTROLLER_PTR )viewController
                                           task:(void (^)(BOOL userCancelled, BOOL userInteractionRequired, NSError *error))task {
    if (!DBClientsManager.authorizedClient) {
        if (!viewController) {
            task(NO, YES, nil);
            return;
        }
        
        [self listenForDropboxAuthCompletion:task];
        
        
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self dismissProgressSpinner];
            
            NSArray<NSString*>* minimalScopes = @[ @"account_info.read",
                                                   @"files.metadata.read",
                                                   @"files.metadata.write",
                                                   @"files.content.read",
                                                   @"files.content.write"];
            
            DBScopeRequest *scopeRequest = [[DBScopeRequest alloc] initWithScopeType:DBScopeTypeUser
                                                                              scopes:minimalScopes
                                                                includeGrantedScopes:NO];
            
#if TARGET_OS_IPHONE
            [DBClientsManager authorizeFromControllerV2:UIApplication.sharedApplication
                                             controller:viewController
                                  loadingStatusDelegate:nil
                                                openURL:^(NSURL *url) { [UIApplication.sharedApplication openURL:url options:@{} completionHandler:nil]; }
                                           scopeRequest:scopeRequest];
#else
            [DBClientsManager authorizeFromControllerDesktopV2:[NSWorkspace sharedWorkspace]
                                                    controller:viewController
                                         loadingStatusDelegate:nil
                                                       openURL:^(NSURL *url) { [[NSWorkspace sharedWorkspace] openURL:url]; }
                                                  scopeRequest:scopeRequest];
#endif
        });
    }
    else {
        task(NO, NO, nil);
    }
}

- (BOOL)handleAuthRedirectUrl:(NSURL*)url {
    return [DBClientsManager handleRedirectURL:url completion:^(DBOAuthResult * _Nullable authResult) {
        if (authResult != nil) {
            [[NSNotificationCenter defaultCenter] postNotificationName:@"isDropboxLinked" object:authResult];
        }
        else {
            slog(@"🔴 Dropbox URL - No Auth Result!!");
        }
    }];
}

- (void)listenForDropboxAuthCompletion:(void (^)(BOOL userCancelled, BOOL userInteractionRequired, NSError *error))task {
    NSNotificationCenter * __weak center = [NSNotificationCenter defaultCenter];
    
    
    
    id __block token = [center addObserverForName:@"isDropboxLinked"
                                           object:nil
                                            queue:nil
                                       usingBlock:^(NSNotification *_Nonnull note) {
        [center removeObserver:token];

        DBOAuthResult *authResult = (DBOAuthResult *)note.object;
        
        if ([authResult isSuccess]) {
            slog(@"✅ Success! User is logged into Dropbox.");
        }
        else if ([authResult isCancel]) {
            slog(@"⚠️ Authorization flow was manually canceled by user!");
        }
        else if ([authResult isError]) {
            slog(@"🔴 Error: %@", authResult);
        }

        if ( DBClientsManager.authorizedClient ) {
            slog(@"✅ Dropbox Linked");
            task(NO, NO, nil);
        }
        else {
            slog(@"🔴 Not Linked");
            slog(@"Error: %@", authResult);
            task(authResult.tag == DBAuthCancel, NO, [Utils createNSError:[NSString stringWithFormat:@"Could not create link to Dropbox: [%@]", authResult] errorCode:-1]);
        }
    }];
    
    
    (void)token;
}

@end
