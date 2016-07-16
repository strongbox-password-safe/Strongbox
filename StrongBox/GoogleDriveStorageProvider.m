//
//  GoogleDriveStorageProvider.m
//  StrongBox
//
//  Created by Mark on 19/11/2014.
//  Copyright (c) 2014 Mark McGuill. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "GoogleDriveStorageProvider.h"

@implementation GoogleDriveStorageProvider
{
}

- (id)init
{
    self.googleDrive = [[GoogleDriveManager alloc] init];

    return self;
}

-(BOOL) isCloudBased
{
    return YES;
}

-(StorageProvider) getStorageId
{
    return kGoogleDrive;
}

- (void)create:(NSString*)desiredFilename data:(NSData*)data parentReference:(NSString*)parentReference viewController:(UIViewController*)viewController completionHandler:(void (^)(NSString *fileName, NSString *fileIdentifier, NSError *error))completion
{
    [self.googleDrive create:viewController withTitle:desiredFilename withData:data parentFolder:parentReference completionHandler:^(GTLDriveFile *file, NSError *error)
     {
         if(error == nil){
             completion(file.title, parentReference, error);
         }
         else
         {
             completion(nil, nil, error);
         }
     }];
}

- (void)read:(SafeMetaData*)safeMetaData viewController:(UIViewController*)viewController completionHandler:(void (^)(NSData* data, NSError* error))completion
{
    [self.googleDrive read:viewController parentFileIdentifier:safeMetaData.fileIdentifier fileName:safeMetaData.fileName completionHandler:^(NSData *data, NSError *error)
    {
         if(error != nil)
         {
             NSLog(@"%@", error);
         }
         
         completion(data, error);
     }];
}

- (void)update:(SafeMetaData*)safeMetaData data:(NSData*)data viewController:(UIViewController*)viewController completionHandler:(void (^)(NSError *error))completion
{
    [self.googleDrive update:viewController parentFileIdentifier:safeMetaData.fileIdentifier fileName:safeMetaData.fileName withData:data completionHandler:^(NSError *error) {
            completion(error);
    }];
}

- (void)delete:(SafeMetaData *)safeMetaData completionHandler:(void (^)(NSError *))completion
{
    // NOTIMPL
}

@end
