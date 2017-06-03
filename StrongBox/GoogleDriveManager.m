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

static NSString *const kMimeType = @"application/octet-stream";

typedef void (^Authenticationcompletion)(NSError *error);

@implementation GoogleDriveManager {
    Authenticationcompletion authenticationcompletion;
}

+ (instancetype)sharedInstance {
    static GoogleDriveManager *sharedInstance = nil;
    static dispatch_once_t onceToken;

    dispatch_once(&onceToken, ^{
        sharedInstance = [[GoogleDriveManager alloc] init];
        // Do any other initialisation stuff here
    });
    return sharedInstance;
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

- (void)initialize {
    // Try to sign in if we have a previous session. This allows us to display the Signout Button
    // state correctly. No need to popup sign in window at this stage, as user may not be using google drive at all

    GIDSignIn *signIn = [GIDSignIn sharedInstance];

    signIn.delegate = self;
    signIn.scopes = @[kGTLRAuthScopeDrive];

    authenticationcompletion = nil;

    [signIn signInSilently];
}

- (BOOL)isAuthorized {
    return [[GIDSignIn sharedInstance] hasAuthInKeychain];
}

- (void)signout {
    [[GIDSignIn sharedInstance] signOut];
    [[GIDSignIn sharedInstance] disconnect];
}

- (void)authenticate:(id<GIDSignInUIDelegate>)viewController completion:(void (^)(NSError *error))completion {
    GIDSignIn *signIn = [GIDSignIn sharedInstance];

    signIn.delegate = self;
    signIn.uiDelegate = viewController;
    signIn.scopes = @[kGTLRAuthScopeDrive];

    authenticationcompletion = completion;
    [signIn signIn];
}

- (void)      signIn:(GIDSignIn *)signIn
    didSignInForUser:(GIDGoogleUser *)user
           withError:(NSError *)error {
    if (error != nil) {
        self.driveService.authorizer = nil;
    }
    else {
        self.driveService.authorizer = user.authentication.fetcherAuthorizer;
    }

    if (authenticationcompletion) {
        authenticationcompletion(error);
        authenticationcompletion = nil;
    }
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)  create:(id<GIDSignInUIDelegate>)viewController
       withTitle:(NSString *)title
        withData:(NSData *)data
    parentFolder:(NSObject *)parentFolder
      completion:(void (^)(GTLRDrive_File *file, NSError *error))handler {
    NSString *parentFolderIdentifier = parentFolder ? ((GTLRDrive_File *)parentFolder).identifier : @"root";

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
        metadata.descriptionProperty = @"StrongBox Password Safe";
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

- (void)readWithOnlyFileId:(id<GIDSignInUIDelegate>)viewController
            fileIdentifier:(NSString *)fileIdentifier
                completion:(void (^)(NSData *data, NSError *error))handler {
    [self getFile:fileIdentifier handler:handler];
}

- (void)            read:(id<GIDSignInUIDelegate>)viewController
    parentFileIdentifier:(NSString *)parentFileIdentifier
                fileName:(NSString *)fileName
              completion:(void (^)(NSData *data, NSError *error))handler {
    parentFileIdentifier = parentFileIdentifier ? parentFileIdentifier : @"root";

    [self authenticate:viewController
            completion:^(NSError *error) {
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
        [SVProgressHUD show];
    });
    
    [self findSafeFile:parentFileIdentifier
              fileName:fileName
            completion:^(GTLRDrive_File *file, NSError *error)
    {
        dispatch_async(dispatch_get_main_queue(), ^{
            [SVProgressHUD popActivity];
        });
        
        if (!file) {
            NSLog(@"Google Drive: No such file found... Trying to use legacy metadata pattern %@", error);

            // NOTE: Legacy, if the file no longer exists, try to load directly using parentFileIdentifier which was the method used previously
            // before. We used to store the id of the safe file, but because of shitty auto backup behaviour in the main PWSSafe app, this
            // ends up pointing at backup files rather than the main file. So now we load by name and parent folder. If that doesn't work we will
            // try loading the file directly by id, which should maintain compatibility with older safes. When people re-add they'll get moved over
            // to the new (parent+title) way of identifiying the file.

            [self getFile:parentFileIdentifier
                  handler:handler];
        }
        else {
            [self getFile:file.identifier
                  handler:handler];
        }
    }];
}

- (void)update:(NSString *)parentFileIdentifier
      fileName:(NSString *)fileName
      withData:(NSData *)data
    completion:(void (^)(NSError *error))handler {
    parentFileIdentifier = parentFileIdentifier ? parentFileIdentifier : @"root";

    [self findSafeFile:parentFileIdentifier
              fileName:fileName
            completion:^(GTLRDrive_File *file, NSError *error)
    {
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

                [self.driveService executeQuery:query
                              completionHandler:^(GTLRServiceTicket *callbackTicket,
                                                                    GTLRDrive_File *uploadedFile,
                                                                    NSError *callbackError) {
                                  if (error) {
                                  NSLog(@"%@", error);
                                  }

                                  handler(error);
                              }];
            }
        }
        else {
            NSLog(@"%@", error);
            handler(error);
        }
    }];
}

- (void)getFilesAndFolders:(id<GIDSignInUIDelegate>)viewController
          withParentFolder:(NSString *)parentFolderIdentifier
                completion:(void (^)(NSArray *folders, NSArray *files, NSError *error))handler {
    parentFolderIdentifier = parentFolderIdentifier ? parentFolderIdentifier : @"root";

    [self authenticate:viewController
            completion:^(NSError *error) {
                if (error) {
                NSLog(@"%@", error);
                handler(nil, nil, error);
                }
                else {
                    [self _getFilesAndFolders:parentFolderIdentifier
                           completion:handler];
                }
            }];
}

- (void)_getFilesAndFolders:(NSString *)parentFileIdentifier
                 completion:(void (^)(NSArray *folders, NSArray *files, NSError *error))handler {
    dispatch_async(dispatch_get_main_queue(), ^{
        [SVProgressHUD show];
    });

    parentFileIdentifier = parentFileIdentifier ? parentFileIdentifier : @"root";

    GTLRDriveQuery_FilesList *query = [GTLRDriveQuery_FilesList query];
    query.q = [NSString stringWithFormat:@"'%@' in parents and trashed=false", parentFileIdentifier ];
    query.fields = @"kind,nextPageToken,files(mimeType,id,name,iconLink,parents,size)";

    [[self driveService] executeQuery:query
                    completionHandler:^(GTLRServiceTicket *ticket,
                                              GTLRDrive_FileList *fileList,
                                              NSError *error)
    {
        dispatch_async(dispatch_get_main_queue(), ^{
            [SVProgressHUD popActivity];
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

            handler(driveFolders, driveFiles, error);
        }
        else {
            NSLog(@"An error occurred: %@", error);

            handler(nil, nil, error);
        }
    }];
}

- (void)getFile:(NSString *)fileIdentifier handler:(void (^)(NSData *, NSError *))handler {
    GTLRDriveQuery_FilesGet *query = [GTLRDriveQuery_FilesGet queryForMediaWithFileId:fileIdentifier];

    [[self driveService] executeQuery:query
                    completionHandler:^(GTLRServiceTicket *ticket,
                                              GTLRDataObject *data,
                                              NSError *error) {
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
