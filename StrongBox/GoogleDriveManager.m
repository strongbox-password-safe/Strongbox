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
#import "SVProgressHUD/SVProgressHUD.h"
#import "real-secrets.h"
#import "Settings.h"

static NSString *const kMimeType = @"application/octet-stream";

typedef void (^Authenticationcompletion)(BOOL userCancelled, NSError *error);

@implementation GoogleDriveManager {
    Authenticationcompletion authenticationcompletion;
}

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
        
        // Try to sign in if we have a previous session. This allows us to display the Signout Button
        // state correctly. No need to popup sign in window at this stage, as user may not be using google drive at all
        
        GIDSignIn *signIn = [GIDSignIn sharedInstance];
        
        signIn.delegate = nil;
        signIn.scopes = @[kGTLRAuthScopeDrive];
        
        authenticationcompletion = nil;
        
        dispatch_async(dispatch_get_main_queue(), ^{ // Must be done on main queue
            [signIn signInSilently];
        });
    }
    
    return self;
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
    return [[GIDSignIn sharedInstance] hasAuthInKeychain];
}

- (void)signout {
    [[GIDSignIn sharedInstance] signOut];
    [[GIDSignIn sharedInstance] disconnect];
}

- (void)authenticate:(UIViewController*)viewController completion:(void (^)(BOOL userCancelled, NSError *error))completion {
    GIDSignIn *signIn = [GIDSignIn sharedInstance];

    signIn.delegate = self;
    signIn.uiDelegate = (id<GIDSignInUIDelegate>)viewController;
    
    signIn.scopes = @[kGTLRAuthScopeDrive];

    authenticationcompletion = completion;

    dispatch_async(dispatch_get_main_queue(), ^{ // Must be done on main queue
        Settings.sharedInstance.suppressPrivacyScreen = YES;
        [signIn signIn];
    });
}

- (void)      signIn:(GIDSignIn *)signIn
    didSignInForUser:(GIDGoogleUser *)user
           withError:(NSError *)error {
    if (error != nil) {
        //NSLog(@"Google Sign In Error: %@", error);
        self.driveService.authorizer = nil;
    }
    else {
        self.driveService.authorizer = user.authentication.fetcherAuthorizer;
    }

    if(error.code == kGIDSignInErrorCodeHasNoAuthInKeychain) {
        return; // Do not call completion if this is a silenet sign and there is no Auth in Key...
    }
    
    if (authenticationcompletion) {
        Settings.sharedInstance.suppressPrivacyScreen = NO;
        //NSLog(@"Google Callback: %@", authenticationcompletion);
        authenticationcompletion(error.code == kGIDSignInErrorCodeCanceled, error);
        authenticationcompletion = nil;
    }
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

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

        // New

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

- (void)readWithOnlyFileId:(UIViewController*)viewController
            fileIdentifier:(NSString *)fileIdentifier
                completion:(void (^)(NSData *data, NSError *error))handler {
    [self getFile:fileIdentifier handler:handler];
}

- (void)            read:(UIViewController*)viewController
    parentFileIdentifier:(NSString *)parentFileIdentifier
                fileName:(NSString *)fileName
              completion:(void (^)(NSData *data, NSError *error))handler {
    parentFileIdentifier = parentFileIdentifier ? parentFileIdentifier : @"root";

    [self authenticate:viewController
            completion:^(BOOL userCancelled, NSError *error) {
                if (error) {
                    NSLog(@"%@", error);
                    handler(nil, error);
                }
                else {
                    [self    _read:parentFileIdentifier
                          fileName:fileName
                        completion:handler];
                }
            }];
}

- (void)_read:(NSString *)parentFileIdentifier fileName:(NSString *)fileName completion:(void (^)(NSData *data, NSError *error))handler {
    parentFileIdentifier = parentFileIdentifier ? parentFileIdentifier : @"root";

    dispatch_async(dispatch_get_main_queue(), ^{
        [SVProgressHUD showWithStatus:@"Locating..."];
    });
    
    [self findSafeFile:parentFileIdentifier
              fileName:fileName
            completion:^(GTLRDrive_File *file, NSError *error)
    {
        dispatch_async(dispatch_get_main_queue(), ^{
            [SVProgressHUD dismiss];
        });
        
        if(error) {
            NSLog(@"%@", error);
            handler(nil, error);
            return;
        }
        else {
            if (!file) {
                NSLog(@"Google Drive: No such file found...");
                error = [Utils createNSError:@"Your database file could not be found on Google Drive. Try removing the database and re-adding it." errorCode:-1];
                handler(nil, error);
                return;
            }
            else {
                [self getFile:file.identifier
                      handler:handler];
            }
        }
    }];
}

- (void)update:(NSString *)parentFileIdentifier
      fileName:(NSString *)fileName
      withData:(NSData *)data
    completion:(void (^)(NSError *error))handler {
    parentFileIdentifier = parentFileIdentifier ? parentFileIdentifier : @"root";

    dispatch_async(dispatch_get_main_queue(), ^{
        [SVProgressHUD showWithStatus:@"Locating..."];
    });
    
    [self findSafeFile:parentFileIdentifier
              fileName:fileName
            completion:^(GTLRDrive_File *file, NSError *error)
    {
        dispatch_async(dispatch_get_main_queue(), ^{
            [SVProgressHUD dismiss];
        });
        
        if (!error) {
            if (!file) {
                handler(error);
            }
            else {
                GTLRUploadParameters *uploadParameters = [GTLRUploadParameters
                                                          uploadParametersWithData:data
                                                                          MIMEType:kMimeType];

                GTLRDriveQuery_FilesUpdate *query = [GTLRDriveQuery_FilesUpdate
                                                     queryWithObject:[GTLRDrive_File object]
                                                                  fileId:file.identifier
                                                        uploadParameters:uploadParameters];

                dispatch_async(dispatch_get_main_queue(), ^{
                    [SVProgressHUD showWithStatus:@"Syncing..."];
                });
                
                [self.driveService executeQuery:query
                              completionHandler:^(GTLRServiceTicket *callbackTicket,
                                                                    GTLRDrive_File *uploadedFile,
                                                                    NSError *callbackError) {
                                  dispatch_async(dispatch_get_main_queue(), ^{
                                      [SVProgressHUD dismiss];
                                  });
                                  
                                  if (callbackError) {
                                      NSLog(@"%@", callbackError);
                                  }

                                  handler(callbackError);
                              }];
            }
        }
        else {
            NSLog(@"%@", error);
            handler(error);
        }
    }];
}

- (void)getFilesAndFolders:(UIViewController*)viewController
          withParentFolder:(NSString *)parentFolderIdentifier
                completion:(void (^)(BOOL userCancelled, NSArray *folders, NSArray *files, NSError *error))handler {
    parentFolderIdentifier = parentFolderIdentifier ? parentFolderIdentifier : @"root";

    [self authenticate:viewController
            completion:^(BOOL userCancelled, NSError *error) {
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
    
    query.fields = @"kind,nextPageToken,files(mimeType,id,name,iconLink,parents,size)";

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

            //NSLog(@"%@", fileList.files);
            
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

- (void)getFile:(NSString *)fileIdentifier handler:(void (^)(NSData *, NSError *))handler {
    GTLRDriveQuery_FilesGet *query = [GTLRDriveQuery_FilesGet queryForMediaWithFileId:fileIdentifier];

    dispatch_async(dispatch_get_main_queue(), ^{
        [SVProgressHUD showWithStatus:@"Reading..."];
    });
    
    [[self driveService] executeQuery:query
                    completionHandler:^(GTLRServiceTicket *ticket,
                                              GTLRDataObject *data,
                                              NSError *error) {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [SVProgressHUD dismiss];
                        });
                        
                        if (error != nil) {
                            NSLog(@"Could not GET file. An error occurred: %@", error);
                        }

                        handler(data.data, error);
                    }];
}

- (void)findSafeFile:(NSString *)parentFileIdentifier
            fileName:(NSString *)fileName
          completion:(void (^)(GTLRDrive_File *file, NSError *error))handler {
    parentFileIdentifier = parentFileIdentifier ? parentFileIdentifier : @"root";

    GTLRDriveQuery_FilesList *query = [GTLRDriveQuery_FilesList query];
    query.q = [NSString stringWithFormat:@"name = '%@' and '%@' in parents and trashed=false", fileName, parentFileIdentifier ? parentFileIdentifier : @"root" ];

    [[self driveService] executeQuery:query
                    completionHandler:^(GTLRServiceTicket *ticket,
                                              GTLRDrive_FileList *fileList,
                                              NSError *error)
    {
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
