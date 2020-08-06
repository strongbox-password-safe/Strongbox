//
//  AppleICloudProvider.m
//  Strongbox
//
//  Created by Mark on 20/09/2017.
//  Copyright © 2017 Mark McGuill. All rights reserved.
//

#import "AppleICloudProvider.h"
#import "StrongboxUIDocument.h"
#import "Strongbox.h"
#import "Utils.h"
#import "SafesList.h"
#import "Settings.h"
#import "iCloudSafesCoordinator.h"
#import "SVProgressHUD.h"

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
        _displayName = NSLocalizedString(@"storage_provider_name_icloud", @"iCloud");
        if([_displayName isEqualToString:@"storage_provider_name_icloud"]) {
            _displayName = @"iCloud";
        }

        _storageId = kiCloud;
        _providesIcons = NO;
        _browsableNew = NO;
        _browsableExisting = NO;
        _rootFolderOnly = NO;
        _immediatelyOfferCacheIfOffline = NO; // Works even if offline (presumably an Apple iCloud cache)
        
        return self;
    }
    else {
        return nil;
    }
}

- (NSString *)icon {
    return @"icloud-32";
}

- (NSURL*)getFullICloudURLWithFileName:(NSString *)filename {
    return [[iCloudSafesCoordinator sharedInstance] getFullICloudURLWithFileName:filename];
}

- (NSString*)getUniqueICloudFilename:(NSString *)prefix extension:(NSString*)extension {
    return [[iCloudSafesCoordinator sharedInstance] getUniqueICloudFilename:prefix extension:extension];
}

- (void)    create:(NSString *)nickName
         extension:(NSString *)extension
              data:(NSData *)data
      parentFolder:(NSObject *)parentFolder
    viewController:(UIViewController *)viewController
        completion:(void (^)(SafeMetaData *metadata, const NSError *error))completion {
    [self create:nickName
       extension:extension
            data:data
suggestedFilename:nil
    parentFolder:parentFolder
  viewController:viewController
      completion:completion];
}

- (void)    create:(NSString *)nickName
         extension:(NSString *)extension
              data:(NSData *)data
 suggestedFilename:(NSString*)suggestedFilename
      parentFolder:(NSObject *)parentFolder
    viewController:(UIViewController *)viewController
        completion:(void (^)(SafeMetaData *metadata, NSError *error))completion {
    NSURL * fileURL = nil;
    
    if(suggestedFilename) {
        NSString* filename = [[suggestedFilename lastPathComponent] stringByDeletingPathExtension];
        NSString* extension = [suggestedFilename pathExtension];
        
        NSString* uniqueFilename = [self getUniqueICloudFilename:filename extension:extension];
        fileURL = [self getFullICloudURLWithFileName:uniqueFilename];
    }
    
    if(!fileURL) {
        fileURL = [self getFullICloudURLWithFileName:[self getUniqueICloudFilename:nickName extension:extension]];
    }

    if(!fileURL || fileURL.absoluteString.length == 0) {
        // Not sure how this can happen but apparently it can...
        completion(nil, [Utils createNSError:@"Could not create an iCloud database because could not find a good path for it!" errorCode:-1]);
        return;
    }
    
    NSLog(@"Want to create file at %@", fileURL);
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [SVProgressHUD showWithStatus:@"Uploading..."];
    });
    
    StrongboxUIDocument * doc = [[StrongboxUIDocument alloc] initWithData:data fileUrl:fileURL];
    //NSLog(@"Loaded File URL: %@ in state: [%@]", [doc.fileURL lastPathComponent], [self stringForDocumentState:doc.documentState]);

    [doc saveToURL:fileURL forSaveOperation:UIDocumentSaveForCreating completionHandler:^(BOOL success) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [SVProgressHUD dismiss];
        });
        
        if (!success) {
            NSLog(@"Failed to create file at %@", fileURL);
            completion(nil, [Utils createNSError:@"Failed to create file" errorCode:-5]);
            return;
        }
        
        NSLog(@"File created at %@", fileURL);
    
        [doc closeWithCompletionHandler:^(BOOL success) {
            if (!success) {
                NSLog(@"Failed to close %@", fileURL);
            }
        }];
        
        SafeMetaData * metadata = [[SafeMetaData alloc] initWithNickName:nickName
                                                         storageProvider:kiCloud
                                                                fileName:[fileURL lastPathComponent]
                                                          fileIdentifier:[fileURL absoluteString]];
        
        completion(metadata, nil);
    }];
}

- (void)pullDatabase:(SafeMetaData *)safeMetaData interactiveVC:(UIViewController *)viewController options:(StorageProviderReadOptions *)options completion:(StorageProviderReadCompletionBlock)completion {
    NSURL *fileUrl = [NSURL URLWithString:safeMetaData.fileIdentifier];

    StrongboxUIDocument * doc = [[StrongboxUIDocument alloc] initWithFileURL:fileUrl];
    
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
            NSLog(@"Failed to open %@", fileUrl);
            completion(kReadResultError, nil, nil, [Utils createNSError:@"Could not read iCloud file. Try restarting your device." errorCode:-6]);
            return;
        }

        //NSLog(@"Loaded File URL: %@ in state: [%@]", [doc.fileURL lastPathComponent], [self stringForDocumentState:doc.documentState]);
        
        NSData* data = doc.data;
        
        [doc closeWithCompletionHandler:^(BOOL success) {
            if (!success) {
                NSLog(@"Failed to close %@", fileUrl);
                completion(kReadResultError, nil, nil, [Utils createNSError:@"Failed to close after reading" errorCode:-6]);
                return;
            }
            
            completion(kReadResultSuccess, data, doc.fileModificationDate, nil);
        }];
    }];
}

- (void)pushDatabase:(SafeMetaData *)safeMetaData interactiveVC:(UIViewController *)viewController data:(NSData *)data isAutoFill:(BOOL)isAutoFill completion:(void (^)(NSError * _Nullable))completion {
    NSURL *fileUrl = [NSURL URLWithString:safeMetaData.fileIdentifier];
    StrongboxUIDocument * doc = [[StrongboxUIDocument alloc] initWithData:data fileUrl:fileUrl];
    
    NSLog(@"Opened File URL: %@ in state: [%@]", [doc.fileURL lastPathComponent], [self stringForDocumentState:doc.documentState]);

    dispatch_async(dispatch_get_main_queue(), ^{
        [SVProgressHUD showWithStatus:@"Updating..."];
    });
    
    [doc saveToURL:fileUrl forSaveOperation:UIDocumentSaveForOverwriting completionHandler:^(BOOL success) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [SVProgressHUD dismiss];
        });
        
        if (!success) {
            NSLog(@"Failed to update file at %@", fileUrl);
            completion([Utils createNSError:@"Failed to update file" errorCode:-5]);
            return;
        }
        
        NSLog(@"File updated at %@", fileUrl);
        
        [doc closeWithCompletionHandler:^(BOOL success) {
            if (!success) {
                NSLog(@"Failed to close %@", fileUrl);
            }
            
            completion(nil);
        }];
    }];
}

- (void)delete:(SafeMetaData*)safeMetaData completion:(void (^)(NSError *error))completion {
    if(safeMetaData.storageProvider != kiCloud) {
        NSLog(@"Safe is not an Apple iCloud safe!");
        return;
    }
 
//    NSURL *url = [NSURL URLWithString:safeMetaData.fileIdentifier];
//    NSURL *ubiq = [[NSFileManager defaultManager] URLForUbiquityContainerIdentifier:nil];
//    NSURL *ubiquitousPackage = [ubiq URLByAppendingPathComponent:safeMetaData.fileName];
    
    NSURL * url = [self getFullICloudURLWithFileName:safeMetaData.fileName];
    
    [self deleteICloudUrl:url safeMetaData:safeMetaData secondAttempt:NO completion:completion];
}

- (void)deleteICloudUrl:(NSURL*)url safeMetaData:(SafeMetaData*)safeMetaData secondAttempt:(BOOL)secondAttempt completion:(void (^)(NSError *error))completion {
    // Wrap in file coordinator
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void) {
        NSFileCoordinator* fileCoordinator = [[NSFileCoordinator alloc] initWithFilePresenter:nil];
        [fileCoordinator coordinateWritingItemAtURL:url
                                            options:NSFileCoordinatorWritingForDeleting
                                              error:nil
                                         byAccessor:^(NSURL* writingURL) {
                                             NSFileManager* fileManager = [[NSFileManager alloc] init];
                                             NSError *error2;
                                             [fileManager removeItemAtURL:writingURL error:&error2];
            if(error2 && !secondAttempt) { // Try to delete by fileIdentifier if fileName failed... could be in a subdirectory
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
    // NOTIMPL
    NSLog(@"NOTIMPL: list");
}

- (void)readWithProviderData:(NSObject *)providerData viewController:(UIViewController *)viewController options:(StorageProviderReadOptions *)options completion:(StorageProviderReadCompletionBlock)completionHandler {
    NSLog(@"NOTIMPL: readWithProviderData");
}

- (void)loadIcon:(NSObject *)providerData viewController:(UIViewController *)viewController
      completion:(void (^)(UIImage *image))completionHandler {
        NSLog(@"NOTIMPL: loadIcon");
}

- (SafeMetaData *)getSafeMetaData:(NSString *)nickName providerData:(NSObject *)providerData {
        NSLog(@"NOTIMPL: getSafeMetaData");
    return nil;
}

@end
