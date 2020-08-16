//
//  GoogleDriveManager.h
//  StrongBox
//
//  Created by Mark McGuill on 05/06/2014.
//  Copyright (c) 2014 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <GoogleSignIn/GoogleSignIn.h>
#import "GTLRDrive.h"
#import "SafeStorageProvider.h"

@interface GoogleDriveManager : NSObject <GIDSignInDelegate>

+ (GoogleDriveManager *)sharedInstance;

@property (NS_NONATOMIC_IOSONLY, getter = isAuthorized, readonly) BOOL authorized;

- (void)                signout;

- (BOOL)handleUrl:(NSURL*)url;

- (void)                      create:(UIViewController *)viewController
                           withTitle:(NSString *)title
                            withData:(NSData *)data
                        parentFolder:(NSObject *)parent
                          completion:(void (^)(GTLRDrive_File *file, NSError *error))handler;

- (void)readWithOnlyFileId:(UIViewController *)viewController
            fileIdentifier:(NSString *)fileIdentifier
              dateModified:(NSDate*)dateModified
                completion:(StorageProviderReadCompletionBlock)handler ;

- (void)read:(UIViewController *)viewController parentFileIdentifier:(NSString *)parentFileIdentifier fileName:(NSString *)fileName options:(StorageProviderReadOptions *)options completion:(StorageProviderReadCompletionBlock)handler;

- (void)update:(UIViewController *)viewController
parentFileIdentifier:(NSString *)parentFileIdentifier
      fileName:(NSString *)fileName
      withData:(NSData *)data
    completion:(StorageProviderUpdateCompletionBlock)handler;

- (void)getFilesAndFolders:(UIViewController *)viewController
          withParentFolder:(NSString *)parentFolderIdentifier
                completion:(void (^)(BOOL userCancelled, NSArray *folders, NSArray *files, NSError *error))handler;

- (void)fetchUrl:(UIViewController *)viewController withUrl:(NSString *)url completion:(void (^)(NSData *data, NSError *error))handler;

@end
