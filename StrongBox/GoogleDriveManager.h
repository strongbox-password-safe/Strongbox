//
//  GoogleDriveManager.h
//  StrongBox
//
//  Created by Mark McGuill on 05/06/2014.
//  Copyright (c) 2014 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "GTLDriveFile.h"

@interface GoogleDriveManager : NSObject

-(BOOL)isAuthorized;

-(void)signout;

-(void)create:(UIViewController*)viewController withTitle:(NSString*)title withData:(NSData*)data parentFolder:(NSString*)parent completionHandler:(void (^)(GTLDriveFile *file, NSError *error))handler;

-(void)readWithOnlyFileId:(UIViewController*)viewController fileIdentifier:(NSString*)fileIdentifier completionHandler:(void (^)(NSData *data, NSError *error))handler;

-(void)read:(UIViewController*)viewController parentFileIdentifier:(NSString*)parentFileIdentifier fileName:(NSString*)fileName completionHandler:(void (^)(NSData *data, NSError *error))handler;

-(void)update:(UIViewController*)viewController
        parentFileIdentifier:(NSString*)parentFileIdentifier
     fileName:(NSString*)fileName
     withData:(NSData*)data
completionHandler:(void (^)(NSError *error))handler;

-(void)getFilesAndFolders:(UIViewController*)viewController
         withParentFolder:(NSString*)parentFolderIdentifier
        completionHandler:(void (^)(NSArray *folders, NSArray *files, NSError *error))handler;

-(void)fetchUrl:(UIViewController*)viewController withUrl:(NSString*)url completionHandler:(void (^)(NSData *data, NSError *error))handler;

@end
