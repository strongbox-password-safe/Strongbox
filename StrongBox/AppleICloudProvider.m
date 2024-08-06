//
//  AppleICloudProvider.m
//  Strongbox
//
//  Created by Mark on 20/09/2017.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import "AppleICloudProvider.h"
#import "StrongboxUIDocument.h"
#import "Strongbox.h"
#import "Utils.h"
#import "DatabasePreferences.h"
#import "iCloudSafesCoordinator.h"
#import "SVProgressHUD.h"
#import "NSDate+Extensions.h"
#import "StrongboxErrorCodes.h"

@implementation AppleICloudProvider

+ (instancetype)sharedInstance {
    static AppleICloudProvider *sharedInstance = nil;
    static dispatch_once_t onceToken;
    
    dispatch_once(&onceToken, ^{
        sharedInstance = [[AppleICloudProvider alloc] init];
    });
    
    return sharedInstance;
}

- (instancetype)init {
    if (self = [super init]) {
        _storageId = kiCloud;
        _providesIcons = NO;
        _browsableNew = NO;
        _browsableExisting = NO;
        _rootFolderOnly = NO;
        _defaultForImmediatelyOfferOfflineCache = NO; 
        _supportsConcurrentRequests = NO; 
        
        return self;
    }
    else {
        return nil;
    }
}

- (NSURL*)getFullICloudURLWithFileName:(NSString *)filename {
    return [[iCloudSafesCoordinator sharedInstance] getFullICloudURLWithFileName:filename];
}

- (NSString*)getUniqueICloudFilename:(NSString *)prefix extension:(NSString*)extension {
    return [[iCloudSafesCoordinator sharedInstance] getUniqueICloudFilename:prefix extension:extension];
}

- (void)create:(NSString *)nickName 
      fileName:(NSString *)fileName
          data:(NSData *)data
  parentFolder:(NSObject *)parentFolder
viewController:(VIEW_CONTROLLER_PTR)viewController
    completion:(void (^)(METADATA_PTR _Nullable, const NSError * _Nullable))completion {
    NSString* extension = fileName.pathExtension;
    NSString* fileNameOnly = fileName.stringByDeletingPathExtension;
    
    NSURL * fileURL = [self getFullICloudURLWithFileName:[self getUniqueICloudFilename:fileNameOnly extension:extension]];

    if(!fileURL || fileURL.absoluteString.length == 0) {
        
        completion(nil, [Utils createNSError:@"Could not create an iCloud database because could not find a good path for it!" errorCode:-1]);
        return;
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{ 
        [SVProgressHUD showWithStatus:NSLocalizedString(@"generic_saving_ellipsis", @"Saving...")];
        
        StrongboxUIDocument * doc = [[StrongboxUIDocument alloc] initWithData:data fileUrl:fileURL];
        

        [doc saveToURL:fileURL forSaveOperation:UIDocumentSaveForCreating completionHandler:^(BOOL success) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [SVProgressHUD dismiss];
            });
            
            if (!success) {
                slog(@"Failed to create file at %@", fileURL);
                completion(nil, [Utils createNSError:@"Failed to create file" errorCode:StrongboxErrorCodes.couldNotCreateICloudFile]);
                return;
            }
            
            slog(@"File created at %@", fileURL);
        
            [doc closeWithCompletionHandler:^(BOOL success) {
                if (!success) {
                    slog(@"Failed to close %@", fileURL);
                }
            }];
            
            DatabasePreferences * metadata = [DatabasePreferences templateDummyWithNickName:nickName
                                                                            storageProvider:kiCloud
                                                                                   fileName:[fileURL lastPathComponent]
                                                                             fileIdentifier:[fileURL absoluteString]];
            
            completion(metadata, nil);
        }];
    });
}


- (void)getModDate:(nonnull METADATA_PTR)safeMetaData completion:(nonnull StorageProviderGetModDateCompletionBlock)completion {
    slog(@"🔴 AppleiCloudProvider::getModDate not impl!");
    
    
}

- (void)pullDatabase:(DatabasePreferences *)safeMetaData interactiveVC:(UIViewController *)viewController options:(StorageProviderReadOptions *)options completion:(StorageProviderReadCompletionBlock)completion {
    dispatch_async(dispatch_get_main_queue(), ^{ 
        NSURL *fileUrl = [NSURL URLWithString:safeMetaData.fileIdentifier];

        StrongboxUIDocument * doc = [[StrongboxUIDocument alloc] initWithFileURL:fileUrl];
        if (!doc) {
            completion(kReadResultError, nil, nil, [Utils createNSError:@"Invalid iCloud URL" errorCode:-6]);
            return;
        }
        
        if (viewController) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [SVProgressHUD showWithStatus:NSLocalizedString(@"storage_provider_status_reading", @"A storage provider is in the process of reading. This is the status displayed on the progress dialog. In english:  Reading...")];
            });
        }
        
        [doc openWithCompletionHandler:^(BOOL success) {
            if (viewController) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [SVProgressHUD dismiss];
                });
            }
             
            if (!success) {
                slog(@"Failed to open %@", fileUrl);
                completion(kReadResultError, nil, nil, [Utils createNSError:@"Could not read iCloud file. Try restarting your device." errorCode:-6]);
                return;
            }

            
            NSData* data = doc.data;
            [doc closeWithCompletionHandler:^(BOOL success) {
                if (!success) {
                    slog(@"Failed to close %@", fileUrl);
                    completion(kReadResultError, nil, nil, [Utils createNSError:@"Failed to close after reading" errorCode:-6]);
                    return;
                }
                
                if ( options && options.onlyIfModifiedDifferentFrom && doc.fileModificationDate && [doc.fileModificationDate isEqualToDateWithinEpsilon:options.onlyIfModifiedDifferentFrom] ) {
                    completion(kReadResultModifiedIsSameAsLocal, nil, nil, nil);
                }
                else {
                    completion(kReadResultSuccess, data, doc.fileModificationDate, nil);
                }
            }];
        }];
    });
}

- (void)pushDatabase:(DatabasePreferences *)safeMetaData interactiveVC:(UIViewController *)viewController data:(NSData *)data completion:(StorageProviderUpdateCompletionBlock)completion {
    NSURL *fileUrl = [NSURL URLWithString:safeMetaData.fileIdentifier];
    
    dispatch_async(dispatch_get_main_queue(), ^{ 
        StrongboxUIDocument * doc = [[StrongboxUIDocument alloc] initWithData:data fileUrl:fileUrl];
        
        slog(@"Opened File URL: %@ in state: [%@]", [doc.fileURL lastPathComponent], [self stringForDocumentState:doc.documentState]);

        if (viewController) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [SVProgressHUD showWithStatus:@"Updating..."];
            });
        }
        
        [doc saveToURL:fileUrl forSaveOperation:UIDocumentSaveForOverwriting completionHandler:^(BOOL success) {
            if (viewController) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [SVProgressHUD dismiss];
                });
            }
            
            if (!success) {
                slog(@"Failed to update file at %@", fileUrl);
                completion(kUpdateResultError, nil, [Utils createNSError:@"Failed to update file" errorCode:-5]);
                return;
            }
            
            slog(@"File updated at %@", fileUrl);
            
            [doc closeWithCompletionHandler:^(BOOL success) {
                if (!success) {
                    slog(@"Failed to close %@", fileUrl);
                }
                
                completion(kUpdateResultSuccess, doc.fileModificationDate, nil);
            }];
        }];
    });
}

- (void)delete:(DatabasePreferences*)safeMetaData completion:(void (^)(NSError *error))completion {
    if(safeMetaData.storageProvider != kiCloud) {
        slog(@"Safe is not an Apple iCloud safe!");
        return;
    }
 



    
    NSURL * url = [self getFullICloudURLWithFileName:safeMetaData.fileName];
    
    [self deleteICloudUrl:url safeMetaData:safeMetaData secondAttempt:NO completion:completion];
}

- (void)deleteICloudUrl:(NSURL*)url safeMetaData:(DatabasePreferences*)safeMetaData secondAttempt:(BOOL)secondAttempt completion:(void (^)(NSError *error))completion {
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void) {
        NSFileCoordinator* fileCoordinator = [[NSFileCoordinator alloc] initWithFilePresenter:nil];
        [fileCoordinator coordinateWritingItemAtURL:url
                                            options:NSFileCoordinatorWritingForDeleting
                                              error:nil
                                         byAccessor:^(NSURL* writingURL) {
                                             NSFileManager* fileManager = [[NSFileManager alloc] init];
                                             NSError *error2;
                                             [fileManager removeItemAtURL:writingURL error:&error2];
            if(error2 && !secondAttempt) { 
                NSURL* urlSecondAttempt = [NSURL URLWithString:safeMetaData.fileIdentifier];
                [self deleteICloudUrl:urlSecondAttempt safeMetaData:safeMetaData secondAttempt:YES completion:completion];
            }
            else {
                 if(completion) {
                     completion(error2);
                 }
            }
        }];
    });
}

- (NSString *)stringForDocumentState:(UIDocumentState)state {
    NSMutableArray * states = [NSMutableArray array];
    if (state == 0) {
        [states addObject:@"Normal"];
    }
    if (state & UIDocumentStateClosed) {
        [states addObject:@"Closed"];
    }
    if (state & UIDocumentStateInConflict) {
        [states addObject:@"In Conflict"];
    }
    if (state & UIDocumentStateSavingError) {
        [states addObject:@"Saving error"];
    }
    if (state & UIDocumentStateEditingDisabled) {
        [states addObject:@"Editing disabled"];
    }
    return [states componentsJoinedByString:@", "];
}

- (void)      list:(NSObject *)parentFolder
    viewController:(UIViewController *)viewController
        completion:(void (^)(BOOL, NSArray<StorageBrowserItem *> *, const NSError *))completion {
    
    slog(@"NOTIMPL: list");
}

- (void)readWithProviderData:(NSObject *)providerData viewController:(UIViewController *)viewController options:(StorageProviderReadOptions *)options completion:(StorageProviderReadCompletionBlock)completionHandler {
    slog(@"NOTIMPL: readWithProviderData");
}

- (void)loadIcon:(NSObject *)providerData viewController:(UIViewController *)viewController
      completion:(void (^)(UIImage *image))completionHandler {
        slog(@"NOTIMPL: loadIcon");
}

- (DatabasePreferences *)getDatabasePreferences:(NSString *)nickName providerData:(NSObject *)providerData {
    slog(@"NOTIMPL: getDatabasePreferences");
    return nil;
}

@end
