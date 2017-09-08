//
//  GoogleDriveStorageProvider.m
//  StrongBox
//
//  Created by Mark on 19/11/2014.
//  Copyright (c) 2014 Mark McGuill. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "GoogleDriveStorageProvider.h"
#import "SVProgressHUD.h"

@implementation GoogleDriveStorageProvider {
    NSMutableDictionary *_iconsByUrl;
}

+ (instancetype)sharedInstance {
    static GoogleDriveStorageProvider *sharedInstance = nil;
    static dispatch_once_t onceToken;
    
    dispatch_once(&onceToken, ^{
        sharedInstance = [[GoogleDriveStorageProvider alloc] init];
    });
    return sharedInstance;
}

- (instancetype)init {
    if (self = [super init]) {
        _displayName = @"Google Drive";
        _icon = @"product32";
        _storageId = kGoogleDrive;
        _cloudBased = YES;
        _providesIcons = YES;
        _browsable = YES;

        _iconsByUrl = [[NSMutableDictionary alloc] init];

        return self;
    }
    else {
        return nil;
    }
}

- (void)    create:(NSString *)nickName
              data:(NSData *)data
      parentFolder:(NSObject *)parentFolder
    viewController:(UIViewController *)viewController
        completion:(void (^)(SafeMetaData *metadata, NSError *error))completion {
    [SVProgressHUD show];

    NSString *desiredFilename = [NSString stringWithFormat:@"%@-strongbox.dat", nickName];

    [[GoogleDriveManager sharedInstance] create:viewController
                                      withTitle:desiredFilename
                                       withData:data
                                   parentFolder:parentFolder
                                     completion:^(GTLRDrive_File *file, NSError *error)
    {
        dispatch_async(dispatch_get_main_queue(), ^{
            [SVProgressHUD popActivity];
        });

        if (error == nil) {
            SafeMetaData *metadata = [self getSafeMetaData:nickName
                                              providerData:file];

            completion(metadata, error);
        }
        else {
            completion(nil, error);
        }
    }];
}

- (void)      read:(SafeMetaData *)safeMetaData
    viewController:(UIViewController *)viewController
        completion:(void (^)(NSData *data, NSError *error))completion {
    [[GoogleDriveManager sharedInstance] read:viewController
                         parentFileIdentifier:safeMetaData.fileIdentifier
                                     fileName:safeMetaData.fileName
                                   completion:^(NSData *data, NSError *error)
    {
        if (error != nil) {
            NSLog(@"%@", error);
            [[GoogleDriveManager sharedInstance] signout];
        }

        completion(data, error);
    }];
}

- (void)update:(SafeMetaData *)safeMetaData
          data:(NSData *)data
    completion:(void (^)(NSError *error))completion {
    [SVProgressHUD show];

    [[GoogleDriveManager sharedInstance] update:safeMetaData.fileIdentifier
                                       fileName:safeMetaData.fileName
                                       withData:data
                                     completion:^(NSError *error) {
                                         dispatch_async(dispatch_get_main_queue(), ^{
                                             [SVProgressHUD popActivity];
                                         });

                                         if(error) {
                                             [[GoogleDriveManager sharedInstance] signout];
                                         }
                                         
                                         completion(error);
                                     }];
}

- (void)      list:(NSObject *)parentFolder
    viewController:(UIViewController *)viewController
        completion:(void (^)(NSArray<StorageBrowserItem *> *items, NSError *error))completion {
    GTLRDrive_File *parent = (GTLRDrive_File *)parentFolder;
    NSMutableArray *driveFiles = [[NSMutableArray alloc] init];

    [[GoogleDriveManager sharedInstance] getFilesAndFolders:viewController
                                           withParentFolder:(parent ? parent.identifier : nil)
                                                 completion:^(NSArray *folders, NSArray *files, NSError *error)
    {
        if (error == nil) {
            NSArray *sorted = [folders sortedArrayUsingComparator:^NSComparisonResult (id obj1, id obj2) {
                GTLRDrive_File *f1 = (GTLRDrive_File *)obj1;
                GTLRDrive_File *f2 = (GTLRDrive_File *)obj2;

                return [f1.name compare:f2.name
                                options:NSCaseInsensitiveSearch];
            }];

            [driveFiles addObjectsFromArray:sorted];

            sorted = [files sortedArrayUsingComparator:^NSComparisonResult (id obj1, id obj2) {
                GTLRDrive_File *f1 = (GTLRDrive_File *)obj1;
                GTLRDrive_File *f2 = (GTLRDrive_File *)obj2;

                return [f1.name compare:f2.name
                                options:NSCaseInsensitiveSearch];
            }];

            [driveFiles addObjectsFromArray:sorted];

            completion([self mapToStorageBrowserItems:driveFiles], nil);
        }
        else {
            [[GoogleDriveManager sharedInstance] signout];
            
            completion(nil, error);
        }
    }];
}

- (void)readWithProviderData:(NSObject *)providerData
              viewController:(UIViewController *)viewController
                  completion:(void (^)(NSData *data, NSError *error))completion {
    [SVProgressHUD showWithStatus:@"Reading..."];

    GTLRDrive_File *file = (GTLRDrive_File *)providerData;

    [[GoogleDriveManager sharedInstance]
     readWithOnlyFileId:viewController
         fileIdentifier:file.identifier
             completion:^(NSData *data, NSError *error) {
                 dispatch_async(dispatch_get_main_queue(), ^{
                     [SVProgressHUD popActivity];
                 });
                 
                 if(error) {
                     [[GoogleDriveManager sharedInstance] signout];
                 }
                 
                 completion(data, error);
             }];
}

- (NSArray<StorageBrowserItem *> *)mapToStorageBrowserItems:(NSArray<GTLRDrive_File *> *)items {
    NSMutableArray<StorageBrowserItem *> *ret = [[NSMutableArray alloc]initWithCapacity:items.count];

    for (GTLRDrive_File *item in items) {
        StorageBrowserItem *mapped = [StorageBrowserItem alloc];

        mapped.name = item.name;
        mapped.folder = [item.mimeType isEqual:@"application/vnd.google-apps.folder"];
        mapped.providerData = item;

        [ret addObject:mapped];
    }

    return ret;
}

- (void)loadIcon:(NSObject *)providerData viewController:(UIViewController *)viewController
      completion:(void (^)(UIImage *image))completionHandler {
    GTLRDrive_File *file = (GTLRDrive_File *)providerData;

    if (_iconsByUrl[file.iconLink] == nil) {
        [[GoogleDriveManager sharedInstance] fetchUrl:viewController
                                              withUrl:file.iconLink
                                           completion:^(NSData *data, NSError *error) {
                                               if (error == nil && data) {
                                               UIImage *image = [UIImage imageWithData:data];

                                               if (image) {
                                               _iconsByUrl[file.iconLink] = image;

                                               completionHandler(image);
                                               }
                                               }
                                               else {
                                               NSLog(@"An error occurred downloading icon: %@", error);
                                               }
                                           }];
    }
    else {
        completionHandler(_iconsByUrl[file.iconLink]);
    }
}

- (SafeMetaData *)getSafeMetaData:(NSString *)nickName providerData:(NSObject *)providerData {
    SafeMetaData *safe = [[SafeMetaData alloc] initWithNickName:nickName
                                                storageProvider:self.storageId
                                            offlineCacheEnabled:YES];

    GTLRDrive_File *file = (GTLRDrive_File *)providerData;

    safe.fileName = file.name;

    NSString *parent = (file.parents)[0];

    safe.fileIdentifier = parent;

    return safe;
}

@end
