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

@interface GoogleDriveManager : NSObject <GIDSignInDelegate, GIDSignInUIDelegate>

+ (GoogleDriveManager *)sharedInstance;

- (void)                initialize;

@property (NS_NONATOMIC_IOSONLY, getter = isAuthorized, readonly) BOOL authorized;

- (void)                signout;

- (void)                      create:(UIViewController *)viewController
                           withTitle:(NSString *)title
                            withData:(NSData *)data
                        parentFolder:(NSObject *)parent
                          completion:(void (^)(GTLRDrive_File *file, NSError *error))handler;

- (void)readWithOnlyFileId:(UIViewController *)viewController fileIdentifier:(NSString *)fileIdentifier completion:(void (^)(NSData *data, NSError *error))handler;

- (void)read:(UIViewController *)viewController parentFileIdentifier:(NSString *)parentFileIdentifier fileName:(NSString *)fileName completion:(void (^)(NSData *data, NSError *error))handler;

- (void)update:(NSString *)parentFileIdentifier
      fileName:(NSString *)fileName
      withData:(NSData *)data
    completion:(void (^)(NSError *error))handler;

- (void)getFilesAndFolders:(UIViewController *)viewController
          withParentFolder:(NSString *)parentFolderIdentifier
                completion:(void (^)(NSArray *folders, NSArray *files, NSError *error))handler;

- (void)fetchUrl:(UIViewController *)viewController withUrl:(NSString *)url completion:(void (^)(NSData *data, NSError *error))handler;

@end
