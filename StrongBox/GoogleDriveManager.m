//
//  GoogleDriveManager.m
//  StrongBox
//
//  Created by Mark McGuill on 05/06/2014.
//  Copyright (c) 2014 Mark McGuill. All rights reserved.
//

#import "GoogleDriveManager.h"
#import "GTLDriveFile.h"
#import "GTLDriveParentReference.h"
#import "GTLUploadParameters.h"
#import "GTLQueryDrive.h"
#import "GTLServiceDrive.h"
#import "GTMOAuth2ViewControllerTouch.h"
#import "GTLDriveConstants.h"
#import "GTLDriveFileList.h"
#import "secrets.h"

static NSString *const kKeychainItemName = @"StrongBox: Google Drive";
static NSString *const kClientId = GOOGLE_CLIENT_ID;
static NSString *const kClientSecret = GOOGLE_CLIENT_SECRET;

@implementation GoogleDriveManager
{
    BOOL _authSet;
}

- (GTLServiceDrive *)driveService
{
    static GTLServiceDrive *service = nil;
    
    if (!service)
    {
        service = [[GTLServiceDrive alloc] init];

        service.shouldFetchNextPages = YES;

        service.retryEnabled = YES;
    }
    
    return service;
}

-(BOOL)isAuthorized
{
    if(!_authSet)
    {
        GTMOAuth2Authentication *auth = [GTMOAuth2ViewControllerTouch
                                         authForGoogleFromKeychainForName:kKeychainItemName
                                         clientID:kClientId
                                         clientSecret:kClientSecret];
        
        if ([auth canAuthorize])
        {
            [[self driveService] setAuthorizer:auth];
            
            _authSet = YES;
            
            return YES;
        }
    }
    else
    {
        return YES;
    }
    
    return NO;
}

-(void)signout
{
    if ([self isAuthorized])
    {
        [GTMOAuth2ViewControllerTouch removeAuthFromKeychainForName:kKeychainItemName];
        [[self driveService] setAuthorizer:nil];
    
        _authSet = NO;
    }
}

-(void)authenticate:(UIViewController*)viewController completionHandler:(void (^)(NSError *error))completionHandler
{
    if (![self isAuthorized])
    {
        GTMOAuth2ViewControllerTouch *authViewController =
        [[GTMOAuth2ViewControllerTouch alloc] initWithScope:kGTLAuthScopeDrive
                                                   clientID:kClientId
                                               clientSecret:kClientSecret
                                           keychainItemName:kKeychainItemName
                                          completionHandler:^(GTMOAuth2ViewControllerTouch *viewController, GTMOAuth2Authentication *auth, NSError *error)
         {
             [viewController dismissViewControllerAnimated:NO completion:nil];
             
             [[self driveService] setAuthorizer:auth];
            
             _authSet = YES;
             
             completionHandler(error);
         }];
        
        [viewController presentViewController:authViewController animated:YES  completion:nil];
    }
}

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

-(void)create:(UIViewController*)viewController withTitle:(NSString*)title withData:(NSData*)data parentFolder:(NSString*)parent completionHandler:(void (^)(GTLDriveFile *file, NSError *error))handler
{
    if (![self isAuthorized])
    {
        [self authenticate:viewController completionHandler:^(NSError *error) {
            if(error)
            {
                NSLog(@"%@", error);
                handler(nil, error);
            }
            else
            {
                [self _create:title withData:data parentFolder:parent completionHandler:handler];
            }
        }];
    }
    else
    {
        [self _create:title withData:data parentFolder:parent completionHandler:handler];
    }
}

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

-(void)_create:(NSString*)title withData:(NSData*)data parentFolder:(NSString*)parent completionHandler:(void (^)(GTLDriveFile *file, NSError *error))handler
{
    GTLQueryDrive *query = [GTLQueryDrive queryForFilesList];
    
    query.q = [NSString stringWithFormat:@"title = '%@' and '%@' in parents and trashed=false", title, parent ? parent : @"root" ];
    
    [[self driveService]  executeQuery:query completionHandler:^(GTLServiceTicket *ticket,
                                                                 GTLDriveFileList *files,
                                                                 NSError *error)
     {
         NSString *fn = [self checkFilenameIsOk:title error:error files:files];
         
         //NSLog(@"%@", fn);
         
         // Got a good filename, create the file

         GTLDriveFile *file = [GTLDriveFile object];

         file.title = fn;
         file.descriptionProperty = @"Strong Box Password Safe";
         file.mimeType = @"application/octet-stream";

         GTLDriveParentReference *parentRef = [GTLDriveParentReference object];
         parentRef.identifier = parent; // identifier property of the folder
         file.parents = @[ parentRef ];

         GTLUploadParameters *uploadParameters =
         [GTLUploadParameters uploadParametersWithData:data
                                         MIMEType:@"application/octet-stream"];

         GTLQueryDrive *query = [GTLQueryDrive queryForFilesInsertWithObject:file
                                                       uploadParameters:uploadParameters];

         [[self driveService] executeQuery:query completionHandler:^(GTLServiceTicket *ticket,
                                                                    GTLDriveFile *updatedFile,
                                                                    NSError *error)
          {
              if(error)
              {
                  NSLog(@"%@", error);
              }
         
              handler(updatedFile, error);
        }];
     }];
}

-(void)readWithOnlyFileId:(UIViewController*)viewController fileIdentifier:(NSString*)fileIdentifier completionHandler:(void (^)(NSData *data, NSError *error))handler
{
    if (![self isAuthorized])
    {
        [self authenticate:viewController completionHandler:^(NSError *error) {
            if(error)
            {
                NSLog(@"%@", error);
                handler(nil, error);
            }
            else
            {
                [self _readWithOnlyFileId:fileIdentifier completionHandler:handler];
            }
        }];
    }
    else
    {
        [self _readWithOnlyFileId:fileIdentifier completionHandler:handler];
    }
}

-(void)read:(UIViewController*)viewController parentFileIdentifier:(NSString*)parentFileIdentifier fileName:(NSString*)fileName completionHandler:(void (^)(NSData *data, NSError *error))handler
{
    if (![self isAuthorized])
    {
        [self authenticate:viewController completionHandler:^(NSError *error) {
            if(error)
            {
                NSLog(@"%@", error);
                handler(nil, error);
            }
            else
            {
                [self _read:parentFileIdentifier fileName:fileName completionHandler:handler];
            }
        }];
    }
    else{
        [self _read:parentFileIdentifier fileName:fileName completionHandler:handler];
    }
}

-(void)_read:(NSString*)parentFileIdentifier fileName:(NSString*)fileName completionHandler:(void (^)(NSData *data, NSError *error))handler
{
    GTLQueryDrive *query = [GTLQueryDrive queryForFilesList];
    
    query.q = [NSString stringWithFormat:@"title = '%@' and '%@' in parents and trashed=false", fileName, parentFileIdentifier ? parentFileIdentifier : @"root" ];
    
    [[self driveService]  executeQuery:query completionHandler:^(GTLServiceTicket *ticket,
                                                                 GTLDriveFileList *files,
                                                                 NSError *error)
     {
         if(files.items != nil && files.items.count > 0)
         {
             GTLDriveFile *file = [files.items objectAtIndex:0];
                
             GTMHTTPFetcher *fetcher =[self.driveService.fetcherService fetcherWithURLString:file.downloadUrl];
             [fetcher beginFetchWithCompletionHandler:^(NSData *data, NSError *error){
                 if(error)
                 {
                     NSLog(@"%@", error);
                 }
                 
                 handler(data, error);
             }];
         }
         else {
             // NOTE: Legacy, if the file no longer exists, try to load directly using parentFileIdentifier which was the method used previously
             // before. We used to store the id of the safe file, but because of shitty auto backup behaviour in the main PWSSafe app, this
             // ends up pointing at backup files rather than the main file. So now we load by name and parent folder. If that doesn't work we will
             // try loading the file directly by id, which should maintain compatibility with older safes. When people re-add they'll get moved over
             // to the new (parent+title) way of identifiying the file.
             
             [self _readWithOnlyFileId:parentFileIdentifier completionHandler:handler];
         }
     }];
}

-(void) _readWithOnlyFileId:(NSString*)fileIdentifier completionHandler:(void (^)(NSData *data, NSError *error))handler
{
    GTLQuery *query = [GTLQueryDrive queryForFilesGetWithFileId:fileIdentifier];
    
    [[self driveService] executeQuery:query completionHandler:^(GTLServiceTicket *ticket,
                                                          GTLDriveFile *file,
                                                          NSError *error)
    {
        if(error)
        {
            NSLog(@"%@", error);
        
            handler(nil, error);
        }
        else
        {
            GTMHTTPFetcher *fetcher =[self.driveService.fetcherService fetcherWithURLString:file.downloadUrl];
            [fetcher beginFetchWithCompletionHandler:^(NSData *data, NSError *error){
                if(error)
                {
                    NSLog(@"%@", error);
                }

                handler(data, error);
            }];
        }
    }];
    
}

-(void)update:(UIViewController*)viewController
    parentFileIdentifier:(NSString*)parentFileIdentifier
     fileName:(NSString*)fileName
     withData:(NSData*)data
completionHandler:(void (^)(NSError *error))handler
{
    if (![self isAuthorized])
    {
        [self authenticate:viewController completionHandler:^(NSError *error) {
            if(error)
            {
                NSLog(@"%@", error);
                handler(error);
            }
            else
            {
                [self _update:parentFileIdentifier fileName:fileName withData:data completionHandler:handler];
            }
        }];
    }
    else
    {
        [self _update:parentFileIdentifier fileName:fileName withData:data completionHandler:handler];
    }
}

-(void)_update:(NSString*)parentFileIdentifier
      fileName:(NSString*)fileName
            withData:(NSData*)data
    completionHandler:(void (^)(NSError *error))handler
{
    GTLQueryDrive *query = [GTLQueryDrive queryForFilesList];
    
    query.q = [NSString stringWithFormat:@"title = '%@' and '%@' in parents and trashed=false", fileName, parentFileIdentifier ? parentFileIdentifier : @"root" ];
    
    [[self driveService]  executeQuery:query completionHandler:^(GTLServiceTicket *ticket,
                                                                 GTLDriveFileList *files,
                                                                 NSError *error)
     {
         if(error)
         {
             NSLog(@"%@", error);
             
             handler(error);
         }
         else
         {
             if(files.items != nil && files.items.count > 0)
             {
                 GTLDriveFile *file = [files.items objectAtIndex:0];
                 
                 GTLUploadParameters *uploadParameters =
                 [GTLUploadParameters uploadParametersWithData:data
                                                      MIMEType:@"application/octet-stream"];
                 
                 GTLQueryDrive *query = [GTLQueryDrive queryForFilesUpdateWithObject:file
                                                                              fileId:file.identifier
                                                                    uploadParameters:uploadParameters];
                 
                 [[self driveService] executeQuery:query completionHandler:^(GTLServiceTicket *ticket,
                                                                             GTLDriveFile *updatedFile,
                                                                             NSError *error)
                  {
                      if(error)
                      {
                          NSLog(@"%@", error);
                      }
                      
                      handler(error);
                  }];
             }
             else{
                 handler(error);
             }
         }
     }];
}

-(void)getFilesAndFolders:(UIViewController*)viewController
         withParentFolder:(NSString*)parentFolderIdentifier
        completionHandler:(void (^)(NSArray *folders, NSArray *files, NSError *error))handler
{
    if (![self isAuthorized])
    {
        [self authenticate:viewController completionHandler:^(NSError *error) {
            if(error)
            {
                NSLog(@"%@", error);
                handler(nil, nil, error);
            }
            else
            {
                [self _getFilesAndFolders:parentFolderIdentifier completionHandler:handler];
            }
        }];
    }
    else
    {
        [self _getFilesAndFolders:parentFolderIdentifier completionHandler:handler];
    }
}

-(void)_getFilesAndFolders:(NSString*)parentFolderIdentifier
        completionHandler:(void (^)(NSArray *folders, NSArray *files, NSError *error))handler
{
    GTLQueryDrive *query = [GTLQueryDrive queryForFilesList];
    
    query.q = [NSString stringWithFormat:@"'%@' in parents and trashed=false", parentFolderIdentifier ? parentFolderIdentifier : @"root" ];
    
    [[self driveService]  executeQuery:query completionHandler:^(GTLServiceTicket *ticket,
                                                                     GTLDriveFileList *files,
                                                                     NSError *error)
    {
        if (error == nil)
        {
            NSMutableArray *driveFolders = [[NSMutableArray alloc] init];
            NSMutableArray *driveFiles = [[NSMutableArray alloc] init];
            
            for(GTLDriveFile *file in files.items)
            {
                if([file.mimeType  isEqual: @"application/vnd.google-apps.folder"])
                {
                    [driveFolders addObject:file];
                }
                else
                {
                    [driveFiles addObject:file];
                }
            }
            
            handler(driveFolders, driveFiles, error);
        }
        else
        {
            NSLog(@"An error occurred: %@", error);

            handler(nil, nil, error);            
        }
    }];
}

-(void)fetchUrl:(UIViewController*)viewController withUrl:(NSString*)url completionHandler:(void (^)(NSData *data, NSError *error))handler;
{
    if (![self isAuthorized])
    {
        [self authenticate:viewController completionHandler:^(NSError *error) {
            if(error)
            {
                NSLog(@"%@", error);
                handler(nil, error);
            }
            else
            {
                [self _fetchUrl:viewController withUrl:url completionHandler:handler];
            }
        }];
    }
    else
    {
        [self _fetchUrl:viewController withUrl:url completionHandler:handler];
    }
}

-(void)_fetchUrl:(UIViewController*)viewController withUrl:(NSString*)url completionHandler:(void (^)(NSData *data, NSError *error))handler;
{
    GTMHTTPFetcher *fetcher =[[self driveService].fetcherService fetcherWithURLString:url];
    [fetcher beginFetchWithCompletionHandler:^(NSData *data, NSError *error)
     {
         if(error)
         {
             NSLog(@"%@", error);
         }
         
         handler(data, error);
     }];
}

// TODO: These do not belong here!

- (NSString *)insertTimestampInFilename:(NSString *)title
{
    NSString *fn=title;
    
    NSDateFormatter *dateFormat = [[NSDateFormatter alloc] init];
    [dateFormat setDateFormat:@"yyyyMMdd-HHmmss"];
    NSDate *date = [[NSDate alloc] init];
    
    NSString* extension = [title pathExtension];
    fn = [NSString stringWithFormat:@"%@-%@.%@",title, [dateFormat stringFromDate:date], extension];
    
    return fn;
}

- (NSString *)checkFilenameIsOk:(NSString *)title error:(NSError *)error files:(GTLDriveFileList *)files
{
    NSString *fn = title;
    
    if (error == nil)
    {
        if(files.items != nil && files.items.count > 0)
        {
            fn = [self insertTimestampInFilename:title];
        }
    }
    else
    {
        NSLog(@"Error checking if file exists: %@", error);
    }
    
    return fn;
}

@end
