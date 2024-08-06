//
//  GoogleDriveManager.m
//  StrongBox
//
//  Created by Mark McGuill on 05/06/2014.
//  Copyright (c) 2014 Mark McGuill. All rights reserved.
//

#import "GoogleDriveManager.h"
#import "Utils.h"
#import "real-secrets.h"
#import "NSDate+Extensions.h"
#import <GoogleSignIn/GoogleSignIn.h>

#if TARGET_OS_IPHONE

#import "SVProgressHUD.h"
#import "AppPreferences.h"

#else

#import "MacAlerts.h"
#import "macOSSpinnerUI.h"

#endif

@interface GoogleDriveManager ()

@property (readonly) GTLRDriveService *driveService;

@end

static NSString *const kMimeType = @"application/octet-stream";

typedef void (^Authenticationcompletion)(BOOL userCancelled, BOOL userInteractionRequired, NSError *error);

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
    self = [super init];
    if (self) {
        GIDSignIn.sharedInstance.configuration = [[GIDConfiguration alloc] initWithClientID:GOOGLE_CLIENT_ID];
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



- (BOOL)isAuthorized {
    return GIDSignIn.sharedInstance.hasPreviousSignIn;
}

- (void)signout {
    [GIDSignIn.sharedInstance signOut];
    
    [GIDSignIn.sharedInstance disconnectWithCompletion:^(NSError * _Nullable error) {
        slog(@"✅ GIDSignIn.sharedInstance disconnectWithCallback finished with [%@]", error);
    }];
}

- (BOOL)handleUrl:(NSURL*)url {
    slog(@"✅ GoogleDriveManager::handleUrl with [%@]", url);    
    return [GIDSignIn.sharedInstance handleURL:url];
}

- (void)authenticate:(VIEW_CONTROLLER_PTR)viewController
          completion:(Authenticationcompletion)completion {
    if (!viewController) { 
        slog(@"✅ Google Drive Sign In - Background Mode - Thread [%@] - completion = [%@]", NSThread.currentThread, completion);

        slog(@"✅ GoogleDriveManager::authenticate - Attempting to restore previous sign in...");
        
        [GIDSignIn.sharedInstance restorePreviousSignInWithCompletion:^(GIDGoogleUser * _Nullable user, NSError * _Nullable error) {
            slog(@"✅ GoogleDriveManager::authenticate - restore previous sign in done with error = [%@] and user = [%@]", error, user);

            [self onDidSignInForUser:user completion:completion backgroundSync:YES withError:error];
        }];

    }
    else {
        slog(@"✅ Google Drive Sign In - Foreground Interactive Mode - Thread [%@]", NSThread.currentThread);
        
        if ( GIDSignIn.sharedInstance.hasPreviousSignIn ) {
            [GIDSignIn.sharedInstance restorePreviousSignInWithCompletion:^(GIDGoogleUser * _Nullable user, NSError * _Nullable error) {
                slog(@"✅ GoogleDriveManager::authenticate - restore previous sign in done with error = [%@] and user = [%@]", error, user);
                
                [self onDidSignInForUser:user completion:completion backgroundSync:NO withError:error];
            }];
        }
        else {
#if TARGET_OS_IPHONE
            AppPreferences.sharedInstance.suppressAppBackgroundTriggers = YES;
#endif
            
                
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
#if TARGET_OS_IPHONE
                [GIDSignIn.sharedInstance signInWithPresentingViewController:viewController
#else
                [GIDSignIn.sharedInstance signInWithPresentingWindow:viewController.view.window
#endif
                                                                        hint:nil
                                                            additionalScopes:@[kGTLRAuthScopeDrive]
                                                                  completion:^(GIDSignInResult * _Nullable signInResult, NSError * _Nullable error) {
                    slog(@"✅ GoogleDriveManager::authenticate - signInWithConfiguration in done with error = [%@] and user = [%@]", error, signInResult.user);

                    [self onDidSignInForUser:signInResult.user completion:completion backgroundSync:NO withError:error];
                }];
            });
        }
    }
}

- (void)onDidSignInForUser:(GIDGoogleUser *)user
                completion:(Authenticationcompletion)completion
            backgroundSync:(BOOL)backgroundSync
                 withError:(NSError *)error {
    if ( error != nil ) {
        slog(@"🔴 Google Sign In Error: %@", error);
        self.driveService.authorizer = nil;
    }
    else {

        self.driveService.authorizer = user.fetcherAuthorizer;
    }
    
#if TARGET_OS_IPHONE
    AppPreferences.sharedInstance.suppressAppBackgroundTriggers = NO;
#endif
    
    
    

    if ( error.code == kGIDSignInErrorCodeHasNoAuthInKeychain ) {
        if ( !backgroundSync ) {
            slog(@"⚠️ Interactive Sync but no auth in keychain for Google Drive");
            
            
            

            
            completion(NO, NO, error);
        }
        else {
            if ( completion ) {


                completion(NO, YES, nil);
            }
        }
    }
    else {
        if ( completion ) {

            completion(error.code == kGIDSignInErrorCodeCanceled, NO, error);
        }
        else {
            slog(@"🔴 EEEEEK - Good Sign In but no AutoCompletion!! NOP - [%@]", NSThread.currentThread);
        }
    }
}



+ (NSString *)sanitizeNickNameForNewFileName:(NSString *)string {
    NSString *trimmed = [string stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    
    trimmed = [[trimmed componentsSeparatedByCharactersInSet:[NSCharacterSet controlCharacterSet]] componentsJoinedByString:@""];
    trimmed = [[trimmed componentsSeparatedByCharactersInSet:[NSCharacterSet illegalCharacterSet]] componentsJoinedByString:@""];

    trimmed = [[trimmed componentsSeparatedByCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"'±|/\\`~@<>:;£$%^&()=+{}[]!\"|?*"]] componentsJoinedByString:@""];
    
    return trimmed;
}

- (void)  create:(VIEW_CONTROLLER_PTR)viewController
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
            slog(@"File already exists under this name. Adding a timestampe to make it unique.");
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
                slog(@"%@", error);
            }

            handler(createdFile, error);
        }];
    }];
}

- (void)readWithOnlyFileId:(VIEW_CONTROLLER_PTR)viewController
            fileIdentifier:(NSString *)fileIdentifier
              dateModified:(NSDate*)dateModified
                completion:(StorageProviderReadCompletionBlock)handler {
    [self getFile:fileIdentifier dateModified:dateModified viewController:viewController handler:handler];
}

- (void)read:(VIEW_CONTROLLER_PTR)viewController
parentOrJson:(NSString *)parentOrJson
    fileName:(NSString *)fileName
     options:(StorageProviderReadOptions *)options
  completion:(StorageProviderReadCompletionBlock)handler {
    [self authenticate:viewController
            completion:^(BOOL userCancelled, BOOL userInteractionRequired, NSError *error) {

        if (error) {
            slog(@"%@", error);
            handler(kReadResultError, nil, nil, error);
        }
        else if (userInteractionRequired) {
            handler(kReadResultBackgroundReadButUserInteractionRequired, nil, nil, nil);
        }
        else {
            [self    _read:parentOrJson
                  fileName:fileName
            viewController:viewController
                   options:options
                completion:handler];
        }
    }];
}

- (void)_read:(NSString *)parentOrJson
     fileName:(NSString *)fileName
viewController:(VIEW_CONTROLLER_PTR)viewController
      options:(StorageProviderReadOptions *)options
   completion:(StorageProviderReadCompletionBlock)handler {
    if (viewController) {
        [self showProgressSpinner:NSLocalizedString(@"generic_status_sp_locating_ellipsis", @"Locating...") viewController:viewController];
    }
    
    [self findSafeFile:parentOrJson
              fileName:fileName
            completion:^(GTLRDrive_File *file, NSError *error)
    {
        if (viewController) {
            [self dismissProgressSpinner];
        }
        
        if(error) {
            slog(@"%@", error);
            handler(kReadResultError, nil, nil, error);
            return;
        }
        else {
            if (!file) {
                slog(@"Google Drive: No such file found...");
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

- (void)getModDate:(NSString *)parentOrJson
          fileName:(NSString *)fileName
        completion:(StorageProviderGetModDateCompletionBlock)handler {
    [self authenticate:nil completion:^(BOOL userCancelled, BOOL userInteractionRequired, NSError *error) {

        if ( error ) {
            slog(@"%@", error);
            handler(YES, nil, error);
        }
        else if (userInteractionRequired) {
            handler(YES, nil, [Utils createNSError:@"User Interaction Required from getModDate" errorCode:346]);
        }
        else {
            [self _getModDate:parentOrJson fileName:fileName completion:handler];
        }
    }];
}

- (void)_getModDate:(NSString *)parentOrJson
           fileName:(NSString *)fileName
         completion:(StorageProviderGetModDateCompletionBlock)handler {
    [self findSafeFile:parentOrJson fileName:fileName completion:^(GTLRDrive_File *file, NSError *error) {
        if ( error ) {
            slog(@"_getModDate: %@", error);
            handler(YES, nil, error);
        }
        else {
            if ( !file ) {
                slog(@"Google Drive::_getModDate No such file found...");
                error = [Utils createNSError:@"Your database file could not be found on Google Drive. Try removing the database and re-adding it." errorCode:-1];
                handler(YES, nil, error);
            }
            else {

                handler(YES, file.modifiedTime.date, nil);
            }
        }
    }];
}

- (void)update:(VIEW_CONTROLLER_PTR)viewController parentOrJson:(NSString *)parentOrJson fileName:(NSString *)fileName withData:(NSData *)data completion:(StorageProviderUpdateCompletionBlock)handler {
    if (viewController) {
        [self showProgressSpinner:NSLocalizedString(@"generic_status_sp_locating_ellipsis", @"Locating...") viewController:viewController];
    }
    
    [self findSafeFile:parentOrJson
              fileName:fileName
            completion:^(GTLRDrive_File *file, NSError *error) {
        
        
        if (viewController) {
            [self dismissProgressSpinner];
        }
        
        if (error || !file) {
            slog(@"%@", error);
            handler(kUpdateResultError, nil, error);
        }
        else {
            GTLRUploadParameters *uploadParameters = [GTLRUploadParameters uploadParametersWithData:data MIMEType:kMimeType];
            GTLRDriveQuery_FilesUpdate *query = [GTLRDriveQuery_FilesUpdate queryWithObject:[GTLRDrive_File object] fileId:file.identifier uploadParameters:uploadParameters];
                        
            query.fields = @"modifiedTime";
            
            if (viewController) {
                [self showProgressSpinner:NSLocalizedString(@"storage_provider_status_syncing", @"Syncing...") viewController:viewController];
            }
        

            
            [self.driveService executeQuery:query completionHandler:^(GTLRServiceTicket *callbackTicket, GTLRDrive_File *uploadedFile, NSError *callbackError) {
                if (viewController) {
                    [self dismissProgressSpinner];
                }












                handler(callbackError ? kUpdateResultError : kUpdateResultSuccess, uploadedFile.modifiedTime.date, callbackError);
            }];
        }
    }];
}

- (void)getFilesAndFolders:(VIEW_CONTROLLER_PTR)viewController
    parentFolderIdentifier:(NSString *)parentFolderIdentifier
                completion:(void (^)(BOOL userCancelled, NSArray *folders, NSArray *files, NSError *error))handler {
    [self authenticate:viewController completion:^(BOOL userCancelled, BOOL userInteractionRequired, NSError *error) {
        if (error) {
            slog(@"%@", error);
            handler(userCancelled, nil, nil, error);
        }
        else {
            [self _getFilesAndFolders:viewController parentFolderIdentifier:parentFolderIdentifier completion:handler];
        }
    }];
}

- (void)_getFilesAndFolders:(VIEW_CONTROLLER_PTR)viewController
     parentFolderIdentifier:(NSString *)parentFolderIdentifier
                 completion:(void (^)(BOOL userCancelled, NSArray *folders, NSArray *files, NSError *error))handler {
    [self showProgressSpinner:NSLocalizedString(@"storage_provider_status_authenticating_listing", @"Listing...") viewController:viewController];











    GTLRDriveQuery_FilesList *query = [GTLRDriveQuery_FilesList query];
    parentFolderIdentifier = parentFolderIdentifier ? parentFolderIdentifier : @"root";

    if(![parentFolderIdentifier isEqualToString:@"root"]) {
        query.q = [NSString stringWithFormat:@"('%@' in parents) and trashed=false", parentFolderIdentifier];
    }
    else {
        query.q = [NSString stringWithFormat:@"(sharedWithMe or ('root' in parents)) and trashed=false"];
    }
    
    query.fields = @"kind,nextPageToken,files(mimeType,id,name,iconLink,parents,size,modifiedTime,ownedByMe)";


    query.pageSize = 1000;
    query.orderBy = @"name";
    
    [[self driveService] executeQuery:query
                    completionHandler:^(GTLRServiceTicket *ticket, GTLRDrive_FileList *fileList, NSError *error) {
        [self dismissProgressSpinner];
        
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
            slog(@"An error occurred: %@", error);
            handler(NO, nil, nil, error);
        }
    }];
}

- (void)findSafeFile:(NSString *)parentOrJson2
            fileName:(NSString *)fileName
          completion:(void (^)(GTLRDrive_File *file, NSError *error))handler {

    
    GTLRDriveQuery_FilesList *query = [GTLRDriveQuery_FilesList query];

    fileName = [fileName stringByReplacingOccurrencesOfString:@"\\" withString:@"\\\\"];
    fileName = [fileName stringByReplacingOccurrencesOfString:@"'" withString:@"\\\'"];
    fileName = [fileName stringByReplacingOccurrencesOfString:@"\"" withString:@"\\\""];

    NSString* parentFolderIdentifier = [self getParentFolderId:parentOrJson2];
    BOOL ownedByMe = [self getOwnedByMe:parentOrJson2];
    
    if ( ownedByMe ) {
        query.q = [NSString stringWithFormat:@"name = '%@' and '%@' in parents and trashed=false", fileName, parentFolderIdentifier ? parentFolderIdentifier : @"root" ];
    }
    else {
        if ( parentFolderIdentifier.length ) {
            query.q = [NSString stringWithFormat:@"name = '%@' and '%@' in parents and trashed=false", fileName, parentFolderIdentifier ];
        }
        else {
            query.q = [NSString stringWithFormat:@"name = '%@' and trashed=false", fileName ];
        }
    }
    
    query.fields = @"files(id,parents,name,modifiedTime)"; 


    query.pageSize = 1000;
    query.orderBy = @"name";

    [[self driveService] executeQuery:query
                    completionHandler:^(GTLRServiceTicket *ticket, GTLRDrive_FileList *fileList, NSError *error) {
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

- (void)fetchUrl:(VIEW_CONTROLLER_PTR)viewController
         withUrl:(NSString *)url
      completion:(void (^)(NSData *data, NSError *error))handler {
    GTMSessionFetcher *fetcher = [[self driveService].fetcherService fetcherWithURLString:url];

    [fetcher beginFetchWithCompletionHandler:^(NSData *data, NSError *error)
    {
        if (error) {
            slog(@"%@", error);
        }

        handler(data, error);
    }];
}

- (void)getFile:(NSString *)fileIdentifier
   dateModified:(NSDate*)dateModified
 viewController:(VIEW_CONTROLLER_PTR)viewController
        handler:(StorageProviderReadCompletionBlock)handler {
    slog(@"✅ getFile - fileIdentifier = [%@]", fileIdentifier);

    GTLRDriveQuery_FilesGet *query = [GTLRDriveQuery_FilesGet queryForMediaWithFileId:fileIdentifier];
    
    if (viewController) {
        [self showProgressSpinner:NSLocalizedString(@"storage_provider_status_reading", @"A storage provider is in the process of reading. This is the status displayed on the progress dialog. In english:  Reading...") viewController:viewController];
    }
    
    [[self driveService] executeQuery:query
                    completionHandler:^(GTLRServiceTicket *ticket, GTLRDataObject *data, NSError *error) {
        if (viewController) {
            [self dismissProgressSpinner];
        }
        
        if (error != nil) {
            slog(@"Could not GET file. An error occurred: %@", error);
            handler(kReadResultError, nil, nil, error);
        }
        else {
            handler(kReadResultSuccess, data.data, dateModified, nil);
        }
    }];
}



- (BOOL)getOwnedByMe:(NSString*)parentOrJson {
    NSDictionary* dict = [self getJsonDict:parentOrJson];
    
    if ( dict ) {
        NSNumber *ownedByMe = dict[@"ownedByMe"];
        return ownedByMe == nil ? YES : ownedByMe.boolValue;
    }
    else {
        return YES;
    }
}

- (NSString*)getParentFolderId:(NSString*)parentOrJson {
    NSDictionary* dict = [self getJsonDict:parentOrJson];
    
    if ( dict ) {
        NSString *parent = dict[@"parent"];
        return parent;
    }
    else {
        return parentOrJson;
    }
}

- (NSDictionary*)getJsonDict:(NSString*)parentOrJson {
    if ( !parentOrJson ) {
        return nil;
    }
    
    NSData* data = [parentOrJson dataUsingEncoding:NSUTF8StringEncoding];
    if ( !data ) {
        slog(@"🔴 Error creating dataUsingEncoding Google Drive database...");
        return nil;
    }

    NSError* error;
    NSDictionary* dict = [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:&error];
    
    if ( !dict ) {

        return nil;
    }
    
    return dict;
}

@end
