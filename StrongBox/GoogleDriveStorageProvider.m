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
#import "Constants.h"

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
        _displayName = NSLocalizedString(@"storage_provider_name_google_drive", @"Google Drive");
        if([_displayName isEqualToString:@"storage_provider_name_google_drive"]) {
            _displayName = @"Google Drive";
        }

        _icon = @"product32";
        _storageId = kGoogleDrive;
        _allowOfflineCache = YES;
        _providesIcons = YES;
        _browsableNew = YES;
        _browsableExisting = YES;
        _rootFolderOnly = NO;
        _immediatelyOfferCacheIfOffline = YES; // Avoid long delay if offline

        _iconsByUrl = [[NSMutableDictionary alloc] init];
        return self;
    }
    else {
        return nil;
    }
}

- (void)    create:(NSString *)nickName
         extension:(NSString *)extension
              data:(NSData *)data
      parentFolder:(NSObject *)parentFolder
    viewController:(UIViewController *)viewController
        completion:(void (^)(SafeMetaData *metadata, const NSError *error))completion {
    [SVProgressHUD show];

    NSString *desiredFilename = [NSString stringWithFormat:@"%@.%@", nickName, extension];

    [[GoogleDriveManager sharedInstance] create:viewController
                                      withTitle:desiredFilename
                                       withData:data
                                   parentFolder:parentFolder
                                     completion:^(GTLRDrive_File *file, NSError *error)
    {
        dispatch_async(dispatch_get_main_queue(), ^{
            [SVProgressHUD dismiss];
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

- (void)readLegacy:(nonnull SafeMetaData *)safeMetaData viewController:(nonnull UIViewController *)viewController isAutoFill:(BOOL)isAutoFill completion:(nonnull void (^)(NSData * _Nullable, const NSError * _Nullable))completion {
    [self read:safeMetaData viewController:viewController completion:completion];
}

- (void)read:(nonnull SafeMetaData *)safeMetaData
viewController:(UIViewController *)viewController
  completion:(nonnull void (^)(NSData * _Nullable, const NSError * _Nullable))completion {
    [[GoogleDriveManager sharedInstance] read:viewController
                         parentFileIdentifier:safeMetaData.fileIdentifier
                                     fileName:safeMetaData.fileName
                                   completion:^(NSData *data, NSError *error) {
        if (error != nil) {
            NSLog(@"%@", error);
            [[GoogleDriveManager sharedInstance] signout];
        }

        completion(data, error);
    }];
}

- (void)readNonInteractive:(nonnull SafeMetaData *)safeMetaData completion:(nonnull void (^)(NSData * _Nullable, const NSError * _Nullable))completion {
    if (!GoogleDriveManager.sharedInstance.authorized) {
        completion(nil, kUserInteractionRequiredError);
        return;
    }
    
    [GoogleDriveManager.sharedInstance readNonInteractive:safeMetaData.fileIdentifier
                                                 fileName:safeMetaData.fileName
                                               completion:^(NSData *data, NSError *error) {
        completion(data, error);
    }];
}

- (void)update:(SafeMetaData *)safeMetaData data:(NSData *)data isAutoFill:(BOOL)isAutoFill completion:(void (^)(NSError * _Nullable))completion {
    [SVProgressHUD show];

    [[GoogleDriveManager sharedInstance] update:safeMetaData.fileIdentifier
                                       fileName:safeMetaData.fileName
                                       withData:data
                                     completion:^(NSError *error) {
                                         dispatch_async(dispatch_get_main_queue(), ^{
                                             [SVProgressHUD dismiss];
                                         });

                                         if(error) {
                                             [[GoogleDriveManager sharedInstance] signout];
                                         }
                                         
                                         completion(error);
                                     }];
}

- (void)      list:(NSObject *)parentFolder
    viewController:(UIViewController *)viewController
        completion:(void (^)(BOOL, NSArray<StorageBrowserItem *> *, const NSError *))completion {

    GTLRDrive_File *parent = (GTLRDrive_File *)parentFolder;
    NSMutableArray *driveFiles = [[NSMutableArray alloc] init];

    [[GoogleDriveManager sharedInstance] getFilesAndFolders:viewController
                                           withParentFolder:(parent ? parent.identifier : nil)
                                                 completion:^(BOOL userCancelled, NSArray *folders, NSArray *files, NSError *error)
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

            completion(NO, [self mapToStorageBrowserItems:driveFiles], nil);
        }
        else {
            [[GoogleDriveManager sharedInstance] signout];
            completion(userCancelled, nil, error);
        }
    }];
}

- (void)readWithProviderData:(NSObject *)providerData
              viewController:(UIViewController *)viewController
                  completion:(void (^)(NSData *data, const NSError *error))completion {
    [SVProgressHUD showWithStatus:NSLocalizedString(@"storage_provider_status_reading", @"A storage provider is in the process of reading. This is the status displayed on the progress dialog. In english:  Reading...")];

    GTLRDrive_File *file = (GTLRDrive_File *)providerData;

    [[GoogleDriveManager sharedInstance]
     readWithOnlyFileId:viewController
         fileIdentifier:file.identifier
             completion:^(NSData *data, NSError *error) {
                 dispatch_async(dispatch_get_main_queue(), ^{
                     [SVProgressHUD dismiss];
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
                                                       self->_iconsByUrl[file.iconLink] = image;

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
    GTLRDrive_File *file = (GTLRDrive_File *)providerData;
    NSString *parent = (file.parents)[0];

    return [[SafeMetaData alloc] initWithNickName:nickName
                                  storageProvider:self.storageId
                                         fileName:file.name
                                   fileIdentifier:parent];
}

- (void)delete:(SafeMetaData *)safeMetaData completion:(void (^)(const NSError *))completion {
    // NOTIMPL
}

@end
