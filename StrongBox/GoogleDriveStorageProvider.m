//
//  GoogleDriveStorageProvider.m
//  StrongBox
//
//  Created by Mark on 19/11/2014.
//  Copyright (c) 2014 Mark McGuill. All rights reserved.
//

#import "GoogleDriveStorageProvider.h"
#import "Constants.h"
#import "Utils.h"

#if TARGET_OS_IPHONE

#import "SVProgressHUD.h"

#else

#import "macOSSpinnerUI.h"
#import "MacUrlSchemes.h"

#endif

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
        _storageId = kGoogleDrive;
        _providesIcons = YES;
        _browsableNew = YES;
        _browsableExisting = YES;
        _rootFolderOnly = NO;
        _defaultForImmediatelyOfferOfflineCache = YES; 
        _supportsConcurrentRequests = NO; 
        _iconsByUrl = [[NSMutableDictionary alloc] init];
        _privacyOptInRequired = YES;
        
        return self;
    }
    else {
        return nil;
    }
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



- (void)create:(NSString *)nickName
      fileName:(NSString *)fileName 
          data:(NSData *)data
  parentFolder:(NSObject *)parentFolder
viewController:(VIEW_CONTROLLER_PTR)viewController
    completion:(void (^)(METADATA_PTR _Nullable, const NSError * _Nullable))completion {
    [self showProgressSpinner:NSLocalizedString(@"storage_provider_status_authenticating_creating", @"Creating...")
               viewController:viewController]; 

    [[GoogleDriveManager sharedInstance] create:viewController
                                      withTitle:fileName
                                       withData:data
                                   parentFolder:parentFolder
                                     completion:^(GTLRDrive_File *file, NSError *error)
    {
        [self dismissProgressSpinner];

        if (error == nil) {
            METADATA_PTR metadata = [self getDatabasePreferences:nickName
                                              providerData:file];

            completion(metadata, error);
        }
        else {
            completion(nil, error);
        }
    }];
}


- (void)getModDate:(nonnull METADATA_PTR)safeMetaData completion:(nonnull StorageProviderGetModDateCompletionBlock)completion {
#if TARGET_OS_IPHONE
    NSString* fileIdentifier = safeMetaData.fileIdentifier;
    NSString* fileName = safeMetaData.fileName;
#else
    NSString* fileIdentifier = safeMetaData.storageInfo;
    NSString* fileName = safeMetaData.fileUrl.lastPathComponent;
#endif

    [GoogleDriveManager.sharedInstance getModDate:fileIdentifier fileName:fileName completion:completion];
}

- (void)pullDatabase:(METADATA_PTR)safeMetaData interactiveVC:(VIEW_CONTROLLER_PTR)viewController options:(StorageProviderReadOptions *)options completion:(StorageProviderReadCompletionBlock)completion {
#if TARGET_OS_IPHONE
    NSString* fileIdentifier = safeMetaData.fileIdentifier;
    NSString* fileName = safeMetaData.fileName;
#else
    NSString* fileIdentifier = safeMetaData.storageInfo;
    NSString* fileName = safeMetaData.fileUrl.lastPathComponent;
#endif
    
    [[GoogleDriveManager sharedInstance] read:viewController
                                 parentOrJson:fileIdentifier
                                     fileName:fileName
                                      options:options
                                   completion:^(StorageProviderReadResult result, NSData * _Nullable data, NSDate * _Nullable dateModified, const NSError * _Nullable error) {
        if (result == kReadResultError) {
            if ( [self shouldSignOutOnError:error]) {
                [[GoogleDriveManager sharedInstance] signout];
            }
        }
        
        completion(result, data, dateModified, error);
    }];
}

- (void)pushDatabase:(METADATA_PTR)safeMetaData interactiveVC:(VIEW_CONTROLLER_PTR)viewController data:(NSData *)data completion:(StorageProviderUpdateCompletionBlock)completion {
    if (viewController) {
        [self showProgressSpinner:@"" viewController:viewController];
    }
    
#if TARGET_OS_IPHONE
    NSString* fileIdentifier = safeMetaData.fileIdentifier;
    NSString* fileName = safeMetaData.fileName;
#else
    NSString* fileIdentifier = safeMetaData.storageInfo;
    NSString* fileName = safeMetaData.fileUrl.lastPathComponent;
#endif
    
    [[GoogleDriveManager sharedInstance] update:viewController
                                   parentOrJson:fileIdentifier
                                       fileName:fileName
                                       withData:data
                                     completion:^(StorageProviderUpdateResult result, NSDate * _Nullable newRemoteModDate, const NSError * _Nullable error) {
        if (viewController) {
            [self dismissProgressSpinner];
        }
        
        if(error) {
            if ( [self shouldSignOutOnError:error]) {
                [[GoogleDriveManager sharedInstance] signout];
            }
        }

        completion(result, newRemoteModDate, error);
    }];
}

- (void)      list:(NSObject *)parentFolder
    viewController:(VIEW_CONTROLLER_PTR)viewController
        completion:(void (^)(BOOL, NSArray<StorageBrowserItem *> *, const NSError *))completion {

    GTLRDrive_File *parent = (GTLRDrive_File *)parentFolder;
    NSMutableArray *driveFiles = [[NSMutableArray alloc] init];

    [[GoogleDriveManager sharedInstance] getFilesAndFolders:viewController
                                     parentFolderIdentifier:(parent ? parent.identifier : nil)
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
            if ( [self shouldSignOutOnError:error]) {
                [[GoogleDriveManager sharedInstance] signout];
            }
            completion(userCancelled, nil, error);
        }
    }];
}

- (void)readWithProviderData:(NSObject *)providerData viewController:(VIEW_CONTROLLER_PTR)viewController options:(StorageProviderReadOptions *)options completion:(StorageProviderReadCompletionBlock)completionHandler {
    if ( viewController ) {
        [self showProgressSpinner:NSLocalizedString(@"storage_provider_status_reading", @"A storage provider is in the process of reading. This is the status displayed on the progress dialog. In english:  Reading...") viewController:viewController];
    }
    
    GTLRDrive_File *file = (GTLRDrive_File *)providerData;
    
    [[GoogleDriveManager sharedInstance] readWithOnlyFileId:viewController
                                             fileIdentifier:file.identifier
                                               dateModified:file.modifiedTime.date
                                                 completion:^(StorageProviderReadResult result, NSData * _Nullable data, NSDate * _Nullable dateModified, const NSError * _Nullable error) {
        if ( viewController ) {
            [self dismissProgressSpinner];
        }
        
        if ( error ) {
            if ( [self shouldSignOutOnError:error]) {
                [[GoogleDriveManager sharedInstance] signout];
            }
            
            completionHandler(kReadResultError, nil, nil, error);
        }
        else {
            completionHandler(kReadResultSuccess, data, dateModified, nil);
        }
    }];
}

- (BOOL)shouldSignOutOnError:(const NSError*)error {
    if ( error && error.domain == NSURLErrorDomain ) {
        if (    error.code == NSURLErrorNotConnectedToInternet ||
                error.code == NSURLErrorTimedOut ) {
            return NO;
        }
    }
    
    return YES;
}

- (NSArray<StorageBrowserItem *> *)mapToStorageBrowserItems:(NSArray<GTLRDrive_File *> *)items {
    NSMutableArray<StorageBrowserItem *> *ret = [[NSMutableArray alloc]initWithCapacity:items.count];

    for (GTLRDrive_File *item in items) {
        StorageBrowserItem *mapped = [StorageBrowserItem alloc];

        mapped.name = item.name;
        mapped.folder = [item.mimeType isEqual:@"application/vnd.google-apps.folder"];
        mapped.providerData = item;
        mapped.identifier = item.identifier;
        
        [ret addObject:mapped];
    }

    return ret;
}

- (void)loadIcon:(NSObject *)providerData
  viewController:(VIEW_CONTROLLER_PTR)viewController
      completion:(void (^)(IMAGE_TYPE_PTR image))completionHandler {
    GTLRDrive_File *file = (GTLRDrive_File *)providerData;

    if (_iconsByUrl[file.iconLink] == nil) {
        [[GoogleDriveManager sharedInstance] fetchUrl:viewController
                                              withUrl:file.iconLink
                                           completion:^(NSData *data, NSError *error) {
           if (error == nil && data) {
#if TARGET_OS_IPHONE
               IMAGE_TYPE_PTR image = [UIImage imageWithData:data];
#else
               IMAGE_TYPE_PTR image = [[NSImage alloc] initWithData:data];
#endif
               if (image) {
                   self->_iconsByUrl[file.iconLink] = image;

                   completionHandler(image);
               }
           }
           else {
       slog(@"An error occurred downloading icon: %@", error);
           }
       }];
    }
    else {
        completionHandler(_iconsByUrl[file.iconLink]);
    }
}








- (METADATA_PTR)getDatabasePreferences:(NSString *)nickName providerData:(NSObject *)providerData {
    GTLRDrive_File *file = (GTLRDrive_File *)providerData;
        
    NSMutableDictionary* dict = [NSMutableDictionary dictionary];
    dict[@"ownedByMe"] = file.ownedByMe == nil ? @(YES) : @(file.ownedByMe.boolValue); 

    NSString *parent = (file.parents)[0];
    if ( parent ) {
        dict [@"parent"] = parent;
    }
    
    if ( file.identifier ) {
        dict [@"originalIdentifierHint"] = file.identifier; 
    }

    NSError* error;
    NSData* data = [NSJSONSerialization dataWithJSONObject:dict
                                                   options:kNilOptions
                                                     error:&error];
    
    if ( !data ) {
        slog(@"🔴 Error creating JSON to Google Drive database: [%@]", error);
        return nil;
    }

    NSString* json = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        
#if TARGET_OS_IPHONE
    return [DatabasePreferences templateDummyWithNickName:nickName
                                  storageProvider:self.storageId
                                         fileName:file.name
                                   fileIdentifier:json];
#else
    NSURLComponents* components = [[NSURLComponents alloc] init];
    components.scheme = kStrongboxGoogleDriveUrlScheme;
    components.path = [NSString stringWithFormat:@"/host/%@", file.name]; 
        
    METADATA_PTR metadata = [MacDatabasePreferences templateDummyWithNickName:nickName
                                                              storageProvider:self.storageId
                                                                      fileUrl:components.URL
                                                                  storageInfo:json];
    
    
    components.queryItems = @[[NSURLQueryItem queryItemWithName:@"uuid" value:metadata.uuid]];
    metadata.fileUrl = components.URL;
    
    return metadata;
#endif
}

- (void)delete:(METADATA_PTR)safeMetaData completion:(void (^)(const NSError *))completion {
    
}

@end
