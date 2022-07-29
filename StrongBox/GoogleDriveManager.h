//
//  GoogleDriveManager.h
//  StrongBox
//
//  Created by Mark McGuill on 05/06/2014.
//  Copyright (c) 2014 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SafeStorageProvider.h"

#import <GoogleAPIClientForREST/GTLRDrive.h>

@interface GoogleDriveManager : NSObject

+ (GoogleDriveManager *)sharedInstance;

@property (NS_NONATOMIC_IOSONLY, getter = isAuthorized, readonly) BOOL authorized;

- (void)signout;

- (BOOL)handleUrl:(NSURL*)url;

- (void)create:(VIEW_CONTROLLER_PTR)viewController
     withTitle:(NSString *)title
      withData:(NSData *)data
  parentFolder:(NSObject *)parent
    completion:(void (^)(GTLRDrive_File *file, NSError *error))handler;

- (void)getModDate:(NSString *)parentOrJson
          fileName:(NSString *)fileName
        completion:(StorageProviderGetModDateCompletionBlock)handler;

- (void)readWithOnlyFileId:(VIEW_CONTROLLER_PTR)viewController
            fileIdentifier:(NSString *)fileIdentifier
              dateModified:(NSDate*)dateModified
                completion:(StorageProviderReadCompletionBlock)handler ;

- (void)read:(VIEW_CONTROLLER_PTR)viewController parentOrJson:(NSString *)parentOrJson fileName:(NSString *)fileName options:(StorageProviderReadOptions *)options completion:(StorageProviderReadCompletionBlock)handler;

- (void)update:(VIEW_CONTROLLER_PTR)viewController
  parentOrJson:(NSString *)parentOrJson
      fileName:(NSString *)fileName
      withData:(NSData *)data
    completion:(StorageProviderUpdateCompletionBlock)handler;

- (void)getFilesAndFolders:(VIEW_CONTROLLER_PTR)viewController
    parentFolderIdentifier:(NSString *)parentFolderIdentifier
                completion:(void (^)(BOOL userCancelled, NSArray *folders, NSArray *files, NSError *error))handler;

- (void)fetchUrl:(VIEW_CONTROLLER_PTR)viewController withUrl:(NSString *)url completion:(void (^)(NSData *data, NSError *error))handler;

@end
