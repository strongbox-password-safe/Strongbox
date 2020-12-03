//
//  GoogleDriveManager.m
//  StrongBox
//
//  Created by Mark McGuill on 05/06/2014.
//  Copyright (c) 2014 Mark McGuill. All rights reserved.
//

#import "GoogleDriveManager.h"
#import "Utils.h"
#import "GTMSessionFetcherService.h"
#import "SVProgressHUD.h"
#import "real-secrets.h"
#import "SharedAppAndAutoFillSettings.h"
#import "NSDate+Extensions.h"

static NSString *const kMimeType = @"application/octet-stream";

typedef void (^Authenticationcompletion)(BOOL userCancelled, BOOL userInteractionRequired, NSError *error);

@interface GoogleDriveManager ()



@property (copy) Authenticationcompletion pendingAuthCompletion;
@property BOOL pendingAuthCompletionIsBackgroundSync;

@end

@implementation GoogleDriveManager

+ (instancetype)sharedInstance {
    static GoogleDriveManager *sharedInstance = nil;
    static dispatch_once_t onceToken;

    dispatch_once(&onceToken, ^{
        sharedInstance = [[GoogleDriveManager alloc] init];
    });
    return sharedInstance;
}

- (instancetype)init {
    if(self = [super init]) {
        [GIDSignIn sharedInstance].clientID = GOOGLE_CLIENT_ID;
    }
    
    return self;
}

- (BOOL)handleUrl:(NSURL*)url {
    return [GIDSignIn.sharedInstance handleURL:url];
}

- (GTLRDriveService *)driveService {
    static GTLRDriveService *service = nil;

    if (!service) {
        service = [[GTLRDriveService alloc] init];
        service.shouldFetchNextPages = YES;
        service.retryEnabled = YES;
    }

    return service;
}

- (BOOL)isAuthorized {
    return GIDSignIn.sharedInstance.hasPreviousSignIn;
}

- (void)signout {
    [[GIDSignIn sharedInstance] signOut];
    [[GIDSignIn sharedInstance] disconnect];
}

- (void)authenticate:(UIViewController*)viewController
          completion:(Authenticationcompletion)completion {
    if (!viewController) { 
        GIDSignIn *signIn = [GIDSignIn sharedInstance];

        signIn.delegate = self;
        signIn.scopes = @[kGTLRAuthScopeDrive];

        
        
        NSLog(@"Google Drive Sign In - Background Mode - Thread [%@] - completion = [%@]", NSThread.currentThread, completion);
        
        self.pendingAuthCompletion = completion;
        self.pendingAuthCompletionIsBackgroundSync = YES;
            
        [signIn restorePreviousSignIn];
    }
    else {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{ 
            NSLog(@"Google Drive Sign In - Foreground Interactive Mode - Thread [%@]", NSThread.currentThread);

            
            GIDSignIn *signIn = [GIDSignIn sharedInstance];

            signIn.delegate = self;
        
            signIn.scopes = @[kGTLRAuthScopeDrive];

            self.pendingAuthCompletion = completion;
            self.pendingAuthCompletionIsBackgroundSync = NO;

            signIn.presentingViewController = viewController;
            
            if(signIn.hasPreviousSignIn) {
                [signIn restorePreviousSignIn];
            }
            else {
                SharedAppAndAutoFillSettings.sharedInstance.suppressPrivacyScreen = YES;
                [signIn signIn];
            }
        });
    }
}

- (void)      signIn:(GIDSignIn *)signIn
    didSignInForUser:(GIDGoogleUser *)user
           withError:(NSError *)error {
    if (error != nil) {
        NSLog(@"Google Sign In Error: %@", error);
        self.driveService.authorizer = nil;
    }
    else {
        NSLog(@"Google Sign In OK - %@", NSThread.currentThread);
        self.driveService.authorizer = user.authentication.fetcherAuthorizer;
    }
    
    SharedAppAndAutoFillSettings.sharedInstance.suppressPrivacyScreen = NO;


    Authenticationcompletion authCompletion = self.pendingAuthCompletion;
    
    
    
    BOOL backgroundSyncAuthCompletionMode = self.pendingAuthCompletionIsBackgroundSync;

    
    
    self.pendingAuthCompletion = nil;
    
    if(error.code == kGIDSignInErrorCodeHasNoAuthInKeychain) {
        if(!backgroundSyncAuthCompletionMode) {
            return; 
        }
        else {
            if (authCompletion) {
                NSLog(@"User Interaction Required for Google Auth - but in Background Sync mode...");
                NSLog(@"Google Callback: %@", authCompletion);
                authCompletion(NO, YES, nil);


            }
        }
    }
    else {
        if (authCompletion) {
            NSLog(@"Google Callback: %@", authCompletion);
            authCompletion(error.code == kGIDSignInErrorCodeCanceled, NO, error);


        }
        else {
            NSLog(@"EEEEEK - Good Sign In but no AutoCompletion!! NOP - [%@]", NSThread.currentThread);
        }
    }
}



+ (NSString *)sanitizeNickNameForNewFileName:(NSString *)string {
    NSString *trimmed = [string stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    
    trimmed = [[trimmed componentsSeparatedByCharactersInSet:[NSCharacterSet controlCharacterSet]] componentsJoinedByString:@""];
    trimmed = [[trimmed componentsSeparatedByCharactersInSet:[NSCharacterSet illegalCharacterSet]] componentsJoinedByString:@""];
    trimmed = [[trimmed componentsSeparatedByCharactersInSet:[NSCharacterSet nonBaseCharacterSet]] componentsJoinedByString:@""];
    trimmed = [[trimmed componentsSeparatedByCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"'±|/\\`~@<>:;£$%^&()=+{}[]!\"|?*"]] componentsJoinedByString:@""];
    
    return trimmed;
}

- (void)  create:(UIViewController*)viewController
       withTitle:(NSString *)titleNick
        withData:(NSData *)data
    parentFolder:(NSObject *)parentFolder
      completion:(void (^)(GTLRDrive_File *file, NSError *error))handler {
    NSString *parentFolderIdentifier = parentFolder ? ((GTLRDrive_File *)parentFolder).identifier : @"root";

    NSString* title = [GoogleDriveManager sanitizeNickNameForNewFileName:titleNick];
    
    [self findSafeFile:parentFolderIdentifier
              fileName:title
            completion:^(GTLRDrive_File *file, NSError *error)
    {
        if (error) {
            handler(nil, error);
            return;
        }

        NSString *fileName = title;

        if (file != nil) {
            NSLog(@"File already exists under this name. Adding a timestampe to make it unique.");
            fileName = [Utils insertTimestampInFilename:title];
        }

        

        GTLRDrive_File *metadata = [GTLRDrive_File object];
        metadata.name = fileName;
        metadata.descriptionProperty = @"Strongbox Database";
        metadata.mimeType = kMimeType;
        metadata.parents = @[ parentFolderIdentifier ];

        GTLRUploadParameters *uploadParameters = [GTLRUploadParameters uploadParametersWithData:data
                                                                                       MIMEType:kMimeType];

        uploadParameters.shouldUploadWithSingleRequest = TRUE;
        GTLRDriveQuery_FilesCreate *query = [GTLRDriveQuery_FilesCreate queryWithObject:metadata
                                                                       uploadParameters:uploadParameters];
        query.fields = @"id, name, mimeType, iconLink, parents, size";

        [[self driveService] executeQuery:query
                        completionHandler:^(GTLRServiceTicket *ticket,
                                                      GTLRDrive_File *createdFile,
                                                      NSError *error)
        {
            if (error) {
                NSLog(@"%@", error);
            }

            handler(createdFile, error);
        }];
    }];
}

- (void)readWithOnlyFileId:(UIViewController *)viewController
            fileIdentifier:(NSString *)fileIdentifier
              dateModified:(NSDate*)dateModified
                completion:(StorageProviderReadCompletionBlock)handler {
    [self getFile:fileIdentifier dateModified:dateModified viewController:viewController handler:handler];
}

- (void)read:(UIViewController *)viewController parentFileIdentifier:(NSString *)parentFileIdentifier fileName:(NSString *)fileName options:(StorageProviderReadOptions *)options completion:(StorageProviderReadCompletionBlock)handler {
    parentFileIdentifier = parentFileIdentifier ? parentFileIdentifier : @"root";

    [self authenticate:viewController
            completion:^(BOOL userCancelled, BOOL userInteractionRequired, NSError *error) {
        NSLog(@"Google Authenticate done [UserCancelled = %hhd]-[error = %@]", userCancelled, error);
        if (error) {
            NSLog(@"%@", error);
            handler(kReadResultError, nil, nil, error);
        }
        else if (userInteractionRequired) {
            handler(kReadResultBackgroundReadButUserInteractionRequired, nil, nil, nil);
        }
        else {
            [self    _read:parentFileIdentifier
                  fileName:fileName
            viewController:viewController
                   options:options
                completion:handler];
        }
    }];
}

- (void)_read:(NSString *)parentFileIdentifier
     fileName:(NSString *)fileName
viewController:(UIViewController*)viewController
      options:(StorageProviderReadOptions *)options
   completion:(StorageProviderReadCompletionBlock)handler {
    parentFileIdentifier = parentFileIdentifier ? parentFileIdentifier : @"root";

    if (viewController) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [SVProgressHUD showWithStatus:NSLocalizedString(@"generic_status_sp_locating_ellipsis", @"Locating...")];
        });
    }
    
    [self findSafeFile:parentFileIdentifier
              fileName:fileName
            completion:^(GTLRDrive_File *file, NSError *error)
    {
        if (viewController) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [SVProgressHUD dismiss];
            });
        }
        
        if(error) {
            NSLog(@"%@", error);
            handler(kReadResultError, nil, nil, error);
            return;
        }
        else {
            if (!file) {
                NSLog(@"Google Drive: No such file found...");
                error = [Utils createNSError:@"Your database file could not be found on Google Drive. Try removing the database and re-adding it." errorCode:-1];
                handler(kReadResultError, nil, nil, error);
                return;
            }
            else {
                GTLRDateTime* dtMod = file.modifiedTime;
                
                if (options && options.onlyIfModifiedDifferentFrom && dtMod) {
                    if ([dtMod.date isEqualToDateWithinEpsilon:options.onlyIfModifiedDifferentFrom]) {
                        handler(kReadResultModifiedIsSameAsLocal, nil, nil, nil);
                        return;
                    }
                }
                
                [self getFile:file.identifier dateModified:dtMod.date viewController:viewController handler:handler];
            }
        }
    }];
}

- (void)update:(UIViewController *)viewController parentFileIdentifier:(NSString *)parentFileIdentifier fileName:(NSString *)fileName withData:(NSData *)data completion:(StorageProviderUpdateCompletionBlock)handler {
    parentFileIdentifier = parentFileIdentifier ? parentFileIdentifier : @"root";

    if (viewController) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [SVProgressHUD showWithStatus:NSLocalizedString(@"generic_status_sp_locating_ellipsis", @"Locating...")];
        });
    }
    
    [self findSafeFile:parentFileIdentifier
              fileName:fileName
            completion:^(GTLRDrive_File *file, NSError *error) {
        if (viewController) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [SVProgressHUD dismiss];
            });
        }
        
        if (error || !file) {
            NSLog(@"%@", error);
            handler(kUpdateResultError, nil, error);
        }
        else {
            GTLRUploadParameters *uploadParameters = [GTLRUploadParameters uploadParametersWithData:data MIMEType:kMimeType];
            GTLRDriveQuery_FilesUpdate *query = [GTLRDriveQuery_FilesUpdate queryWithObject:[GTLRDrive_File object] fileId:file.identifier uploadParameters:uploadParameters];
            query.fields = @"modifiedTime";

            if (viewController) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [SVProgressHUD showWithStatus:NSLocalizedString(@"storage_provider_status_syncing", @"Syncing...")];
                });
            }
            
            [self.driveService executeQuery:query completionHandler:^(GTLRServiceTicket *callbackTicket, GTLRDrive_File *uploadedFile, NSError *callbackError) {
                if (viewController) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [SVProgressHUD dismiss];
                    });
                }

                handler(callbackError ? kUpdateResultError : kUpdateResultSuccess, uploadedFile.modifiedTime.date, callbackError);
            }];
        }
    }];
}

- (void)getFilesAndFolders:(UIViewController*)viewController
          withParentFolder:(NSString *)parentFolderIdentifier
                completion:(void (^)(BOOL userCancelled, NSArray *folders, NSArray *files, NSError *error))handler {
    parentFolderIdentifier = parentFolderIdentifier ? parentFolderIdentifier : @"root";

    [self authenticate:viewController completion:^(BOOL userCancelled, BOOL userInteractionRequired, NSError *error) {
        if (error) {
            NSLog(@"%@", error);
            handler(userCancelled, nil, nil, error);
        }
        else {
            [self _getFilesAndFolders:parentFolderIdentifier completion:handler];
        }
    }];
}

- (void)_getFilesAndFolders:(NSString *)parentFileIdentifier
                 completion:(void (^)(BOOL userCancelled, NSArray *folders, NSArray *files, NSError *error))handler {
    dispatch_async(dispatch_get_main_queue(), ^{
        [SVProgressHUD show];
    });

    GTLRDriveQuery_FilesList *query = [GTLRDriveQuery_FilesList query];
    
    parentFileIdentifier = parentFileIdentifier ? parentFileIdentifier : @"root";

    if(![parentFileIdentifier isEqualToString:@"root"]) {
        query.q = [NSString stringWithFormat:@"('%@' in parents) and trashed=false", parentFileIdentifier];
    }
    else {
        query.q = [NSString stringWithFormat:@"(sharedWithMe or ('root' in parents)) and trashed=false"];
        
    }
    
    query.fields = @"kind,nextPageToken,files(mimeType,id,name,iconLink,parents,size,modifiedTime)";

    [[self driveService] executeQuery:query
                    completionHandler:^(GTLRServiceTicket *ticket,
                                              GTLRDrive_FileList *fileList,
                                              NSError *error)
    {
        dispatch_async(dispatch_get_main_queue(), ^{
            [SVProgressHUD dismiss];
        });
        
        if (error == nil) {
            NSMutableArray *driveFolders = [[NSMutableArray alloc] init];
            NSMutableArray *driveFiles = [[NSMutableArray alloc] init];

            
            
            for (GTLRDrive_File *file in fileList.files) {
                if ([file.mimeType isEqual:@"application/vnd.google-apps.folder"]) {
                    [driveFolders addObject:file];
                }
                else {
                    [driveFiles addObject:file];
                }
            }

            handler(NO, driveFolders, driveFiles, error);
        }
        else {
            NSLog(@"An error occurred: %@", error);

            handler(NO, nil, nil, error);
        }
    }];
}

- (void)getFile:(NSString *)fileIdentifier
   dateModified:(NSDate*)dateModified
 viewController:(UIViewController*)viewController
        handler:(StorageProviderReadCompletionBlock)handler {
    GTLRDriveQuery_FilesGet *query = [GTLRDriveQuery_FilesGet queryForMediaWithFileId:fileIdentifier];
    
    if (viewController) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [SVProgressHUD showWithStatus:NSLocalizedString(@"storage_provider_status_reading", @"A storage provider is in the process of reading. This is the status displayed on the progress dialog. In english:  Reading...")];
        });
    }
    
    [[self driveService] executeQuery:query
                    completionHandler:^(GTLRServiceTicket *ticket, GTLRDataObject *data, NSError *error) {
        if (viewController) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [SVProgressHUD dismiss];
            });
        }
        
        if (error != nil) {
            NSLog(@"Could not GET file. An error occurred: %@", error);
            handler(kReadResultError, nil, nil, error);
        }
        else {
            handler(kReadResultSuccess, data.data, dateModified, nil);
        }
    }];
}

- (void)findSafeFile:(NSString *)parentFileIdentifier
            fileName:(NSString *)fileName
          completion:(void (^)(GTLRDrive_File *file, NSError *error))handler {
    parentFileIdentifier = parentFileIdentifier ? parentFileIdentifier : @"root";

    GTLRDriveQuery_FilesList *query = [GTLRDriveQuery_FilesList query];

    fileName = [fileName stringByReplacingOccurrencesOfString:@"\\" withString:@"\\\\"];
    fileName = [fileName stringByReplacingOccurrencesOfString:@"'" withString:@"\\\'"];
    fileName = [fileName stringByReplacingOccurrencesOfString:@"\"" withString:@"\\\""];

    query.q = [NSString stringWithFormat:@"name = '%@' and '%@' in parents and trashed=false", fileName, parentFileIdentifier ? parentFileIdentifier : @"root" ];
    query.fields = @"files(id,name,modifiedTime)"; 
    
    [[self driveService] executeQuery:query
                    completionHandler:^(GTLRServiceTicket *ticket,
                                              GTLRDrive_FileList *fileList,
                                              NSError *error) {
        if (!error) {
            if (fileList.files != nil && fileList.files.count > 0) {
                GTLRDrive_File *file = fileList.files[0];
                handler(file, error);
            }
            else {
                handler(nil, error);
            }
        }
        else {
            handler(nil, error);
        }
    }];
}

- (void)fetchUrl:(UIViewController *)viewController
         withUrl:(NSString *)url
      completion:(void (^)(NSData *data, NSError *error))handler {
    GTMSessionFetcher *fetcher = [[self driveService].fetcherService fetcherWithURLString:url];

    [fetcher beginFetchWithCompletionHandler:^(NSData *data, NSError *error)
    {
        if (error) {
            NSLog(@"%@", error);
        }

        handler(data, error);
    }];
}

@end
