//
//  OneDriveStorageProvider.m
//  Strongbox-iOS
//
//  Created by Mark on 25/07/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
//

#import "OneDriveStorageProvider.h"
#import "Utils.h"
#import "SVProgressHUD.h"
#import "OneDriveSDK.h"
#import "NSDate+Extensions.h"

@interface OneDriveStorageProvider()

@property (nonatomic) ODClient *odClient;

@end

static NSString * const kApplicationId = @"708058b4-71de-4c54-ae7f-0e6f5872e953";

@implementation OneDriveStorageProvider

+ (instancetype)sharedInstance {
    static OneDriveStorageProvider *sharedInstance = nil;
    static dispatch_once_t onceToken;
    
    dispatch_once(&onceToken, ^{
        sharedInstance = [[OneDriveStorageProvider alloc] init];
    });
    return sharedInstance;
}

- (instancetype)init {
    if (self = [super init]) {
        _storageId = kOneDrive;
        _providesIcons = NO;
        _browsableNew = YES;
        _browsableExisting = YES;
        _rootFolderOnly = NO;
        _immediatelyOfferCacheIfOffline = YES; // Avoid long delay
        _supportsConcurrentRequests = NO; // TODO: Possibly
        
        [ODClient setMicrosoftAccountAppId:kApplicationId scopes:@[@"onedrive.readwrite", @"offline_access"]];
        
        // MMcG: 10-Oct-2018 - Originally had OneDrive for Business as a separate provider but it turns out you can do
        // this, and set it up as both personal and business. Deciding for simplicity to keep it to only one procider
        // and not support multi accounting. Also, the underlying cookies are shared so it would be difficult to manage
        // this...
        
        static NSString * const kBusinessApplicationId = @"8c10a31a-0f4b-4931-a450-c2959b0a7169";
        static NSString * const kBusinessRedirectUri = @"https://azure-redirect-uri.strongboxsafe.com";

        //[ODClient setActiveDirectoryAppId:kBusinessApplicationId redirectURL:kBusinessRedirectUri];
        
        [ODClient setActiveDirectoryAppId:kBusinessApplicationId
                               resourceId:@"https://graph.microsoft.com/"
                              apiEndpoint:@"https://graph.microsoft.com/v1.0/me"
                              redirectURL:kBusinessRedirectUri];
        
//        [ODClient setActiveDirectoryAppId:kBusinessApplicationId
//                               resourceId:kBusinessApplicationId
//                              apiEndpoint:@"https://graph.microsoft.com/v1.0/me"
//                              redirectURL:kBusinessRedirectUri];

        // Testing Code...
        
//        ODClient* blah = [ODClient loadCurrentClient];
//
//        if(blah) {
//            [blah signOutWithCompletion:^(NSError *error) {
//                NSLog(@"Signed Out");
//                NSHTTPCookieStorage *cookieStorage = [NSHTTPCookieStorage sharedHTTPCookieStorage];
//                for (NSHTTPCookie *each in cookieStorage.cookies) {
//                    NSLog(@"%@", each);
//                    [cookieStorage deleteCookie:each]; }
//            }];
//        }
//        else {
//            NSHTTPCookieStorage *cookieStorage = [NSHTTPCookieStorage sharedHTTPCookieStorage];
//            for (NSHTTPCookie *each in cookieStorage.cookies) { NSLog(@"%@", each); [cookieStorage deleteCookie:each]; }
//        }
        
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
    [self authWrapperWithCompletion:viewController completion:^(BOOL userInteractionRequired, NSError *error) {
        if(error) {
            completion(nil, error);
            return;
        }
        
        [SVProgressHUD show];
        
        NSString *desiredFilename = [NSString stringWithFormat:@"%@.%@", nickName, extension];
        
        ODItem* parent = ((ODItem*)parentFolder);
        
        NSString *parentItemId = parent == nil ? @"root" :
        (parent.remoteItem == nil ? parent.id : parent.remoteItem.id);
        
        ODItemContentRequest *request;
        if(parent.remoteItem) {
            request = [[[[self.odClient drives:parent.remoteItem.parentReference.driveId] items:parent.remoteItem.id] itemByPath:desiredFilename] contentRequest];
        }
        else {
            request = [[[[self.odClient drive] items:parentItemId] itemByPath:desiredFilename] contentRequest];
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [SVProgressHUD showWithStatus:@"Updating..."];
        });
        
        [request uploadFromData:data completion:^(ODItem *response, NSError *error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [SVProgressHUD dismiss];
            });
            
            if (error == nil) {
                //NSLog(@"%@ - %@", response, error);
                
                SafeMetaData *metadata = [self getSafeMetaData:nickName
                                                  providerData:response];

                completion(metadata, nil);
            }
            else {
                NSLog(@"OneDrive create error: %@", error);
                completion(nil, error);
                return;
            }
        }];
    }];

}

- (void)pullDatabase:(SafeMetaData *)safeMetaData interactiveVC:(UIViewController *)viewController options:(StorageProviderReadOptions *)options completion:(StorageProviderReadCompletionBlock)completion {
    [self authWrapperWithCompletion:viewController completion:^(BOOL userInteractionRequired, NSError *error) {
        if(error) {
            completion(kReadResultError, nil, nil, error);
            [self signout:^(NSError *error) { }];  // Signout if something
            return;
        }
        
        if (userInteractionRequired) {
            completion(kReadResultBackgroundReadButUserInteractionRequired, nil, nil, nil);
            return;
        }
        
        if (viewController) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [SVProgressHUD showWithStatus:NSLocalizedString(@"generic_status_sp_locating_ellipsis", @"Locating...")];
            });
        }
        
        
        [self providerDataFromMetadata:safeMetaData completion:^(ODItem *item, NSError *error) {
            if (viewController) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [SVProgressHUD dismiss];
                });
            }
            
            if(error || !item) {
                if(!item) {
                    error = [Utils createNSError:@"Could not locate the database file. Has it been renamed or moved?" errorCode:45];
                }
                
                NSLog(@"OneDrive Read: %@", error);
                completion(kReadResultError, nil, nil, error);
                return;
            }
            
            [self readWithProviderData:item viewController:viewController options:options completion:completion];
        }];
    }];
}

- (void)readWithProviderData:(NSObject *)providerData viewController:(UIViewController *)viewController options:(StorageProviderReadOptions *)options completion:(StorageProviderReadCompletionBlock)completion {
    [self authWrapperWithCompletion:viewController completion:^(BOOL userInteractionRequired, NSError *error) {
        if(error) {
            [self.odClient signOutWithCompletion:^(NSError *error) { // Signout if something goes wrong
                completion(kReadResultError, nil, nil, error);
            }];
            return;
        }
                      
        if (userInteractionRequired) {
            completion(kReadResultBackgroundReadButUserInteractionRequired, nil, nil, nil);
            return;
        }

        ODItem* item = (ODItem*)providerData;
        
        NSLog(@"OneDrive Reading: [%@]-[%@]", item, item.lastModifiedDateTime);
                
        NSDate* dtMod = item.lastModifiedDateTime;
        NSDate* dtMod2 = options.onlyIfModifiedDifferentFrom;
    
        if (options && dtMod2 && dtMod) {
            if ([dtMod isEqualToDateWithinEpsilon:dtMod2]) {
                completion(kReadResultModifiedIsSameAsLocal, nil, nil, nil);
                return;
            }
        }

        ODItemContentRequest *request;
        
        request = [[[self.odClient drives:item.parentReference.driveId] items:item.id] contentRequest];
        
        if (viewController) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [SVProgressHUD showWithStatus:NSLocalizedString(@"storage_provider_status_reading", @"A storage provider is in the process of reading. This is the status displayed on the progress dialog. In english:  Reading...")];
            });
        }
        
        [request downloadWithCompletion:^(NSURL *filePath, NSURLResponse *urlResponse, NSError *error){
            if (viewController) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [SVProgressHUD dismiss];
                });
            }
            
            if(error) {
                NSLog(@"%@", error);
                completion(kReadResultError, nil, nil, error);
                return;
            }
            
            // The file path to the item on disk. This is a temporary file and will be removed
            // after the block is done executing.
            
            //        NSLog(@"File Url: %@", filePath);
            //        NSLog(@"File Path: %@", filePath.path);
            //        NSLog(@"Exists: %hhd", [[NSFileManager defaultManager] fileExistsAtPath:filePath.path]);
    
            
            NSData *data = [[NSFileManager defaultManager] contentsAtPath:filePath.path];
            
            //NSLog(@"OneDrive Read %lu bytes.", (unsigned long)data.length);
            
            completion(kReadResultSuccess, data, item.lastModifiedDateTime, nil);
        }];
    }];
}

- (void)pushDatabase:(SafeMetaData *)safeMetaData interactiveVC:(UIViewController *)viewController data:(NSData *)data completion:(StorageProviderUpdateCompletionBlock)completion {
    [self authWrapperWithCompletion:viewController completion:^(BOOL userInteractionRequired, NSError *error) {
        if(error) {
            completion(kUpdateResultError, nil, error);
            return;
        }
                      
        if (userInteractionRequired) {
           completion(kUpdateResultUserInteractionRequired, nil, nil);
           return;
        }

        if (viewController) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [SVProgressHUD showWithStatus:NSLocalizedString(@"generic_status_sp_locating_ellipsis", @"Locating...")];
            });
        }

        [self providerDataFromMetadata:safeMetaData completion:^(ODItem *item, NSError *error) {
            if (viewController) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [SVProgressHUD dismiss];
                });
            }
            
            if(error || !item) {
                if(!item) {
                    error = [Utils createNSError:@"Could not locate the database file. Has it been renamed or moved?" errorCode:45];
                }
                
                NSLog(@"OneDrive Read: %@", error);
                completion(kUpdateResultError, nil, error);
                return;
            }
            
            ODItemContentRequest *request;
            request = [[[self.odClient drives:item.parentReference.driveId] items:item.id] contentRequest];
            
            if (viewController) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [SVProgressHUD showWithStatus:@"Updating..."];
                });
            }
            
            [request uploadFromData:data completion:^(ODItem *response, NSError *error) {
                if (viewController) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [SVProgressHUD dismiss];
                    });
                }
                
                if (error) {
                    completion(kUpdateResultError, nil, error);
                }
                else {
                    completion(kUpdateResultSuccess, response.lastModifiedDateTime, nil);
                }
            }];
        }];
    }];
}

- (void)      list:(NSObject *)parentFolder
    viewController:(UIViewController *)viewController
        completion:(void (^)(BOOL, NSArray<StorageBrowserItem *> *, const NSError *))completion {
    [self authWrapperWithCompletion:viewController completion:^(BOOL userInteractionRequired, NSError *error) {
        if(error) {
            completion(error.code == ODAuthCanceled, nil, error);
            return;
        }
                      
       if (userInteractionRequired) {
           completion(NO, nil, nil);
           return;
       }

        
        ODItem* parent = ((ODItem*)parentFolder);
        
        NSString *parentItemId = parent == nil ? @"root" :
            (parent.remoteItem == nil ? parent.id : parent.remoteItem.id);
        
        ODChildrenCollectionRequest *request;
        if(parent.remoteItem) {
            request = [[[[self.odClient drives:parent.remoteItem.parentReference.driveId] items:parent.remoteItem.id] children] request];
        }
        else {
            request = [[[[self.odClient drive] items:parentItemId] children] request];
        }
        
        [self listRecursive:request error:error existingItems:[NSMutableArray array] completion:completion];
    }];
}

- (void)listRecursive:(ODChildrenCollectionRequest *)request
      error:(NSError *)error
      existingItems:(NSMutableArray<StorageBrowserItem*>*)existingItems
 completion:(void (^)(BOOL userCancelled, NSArray<StorageBrowserItem *> *items, const NSError *error))completion
{
    [request getWithCompletion:^(ODCollection *response, ODChildrenCollectionRequest *nr, NSError *error) {
        if(error) {
            NSLog(@"%@", error);
            completion(NO, nil, error);
            return;
        }

        NSArray* chunk = [self mapToBrowserItems:response.value];
        [existingItems addObjectsFromArray:chunk];
        
        if(nr) {
            [self listRecursive:nr error:error existingItems:existingItems completion:completion];
        }
        else {
            NSLog(@"Got all items: [%lu]", (unsigned long)existingItems.count);
            completion(NO, [NSArray arrayWithArray:existingItems], nil);
        }
    }];
}

- (SafeMetaData *)getSafeMetaData:(NSString *)nickName providerData:(NSObject *)providerData {
    ODItem *file = (ODItem *)providerData;
   
    NSDictionary* dp = [NSDictionary dictionaryWithObjectsAndKeys:file.parentReference.driveId, @"driveId", file.parentReference.id, @"parentFolderId", nil];
    
    NSError* error;
    NSData* data = [NSJSONSerialization dataWithJSONObject:dp options:0 error:&error];
    
    if(error) {
        NSLog(@"%@", error);
        return nil;
    }
   
    NSString *json = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    //NSLog(@"%@", json);
    NSString *parent = json;
    
    return [[SafeMetaData alloc] initWithNickName:nickName
                                  storageProvider:self.storageId
                                         fileName:file.name
                                   fileIdentifier:parent];
}

- (void)providerDataFromMetadata:(SafeMetaData*)metadata completion:(void(^)(ODItem* item, NSError* error))completion {
    NSData* data = [metadata.fileIdentifier dataUsingEncoding:NSUTF8StringEncoding];
    
    NSError *error;
    NSDictionary* dictionary = (NSDictionary*)[NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
    
    if(error) {
        completion(nil, error);
        return;
    }
    
    NSString* driveId = [dictionary objectForKey:@"driveId"];
    NSString* parentFolderId = [dictionary objectForKey:@"parentFolderId"];
    
    //NSLog(@"Searching for drive:[%@] parent:[%@] name:[%@]", driveId, parentFolderId, metadata.fileName);
    
    ODChildrenCollectionRequest *request = [[[[self.odClient drives:driveId] items:parentFolderId] children] request];
    
    [self findItemRecursive:request target:metadata.fileName completion:^(ODItem *item, NSError *error) {
        completion(item, error);
    }];
}

- (void)findItemRecursive:(ODChildrenCollectionRequest *)request target:(NSString*)target completion:(void(^)(ODItem* item, NSError* error))completion {
    [request getWithCompletion:^(ODCollection *response, ODChildrenCollectionRequest *nr, NSError *error) {
        if(error) {
            NSLog(@"%@", error);
            completion(nil, error);
            return;
        }
        
        ODItem* foundItem = nil;
        for (ODItem* item in response.value) {
            if([item.name compare:target] == NSOrderedSame) {
                foundItem = item;
                break;
            }
        }
        
        if(!foundItem && nr) {
            [self findItemRecursive:nr target:target completion:completion];
        }
        else {
            completion(foundItem, nil);
        }
    }];
}

- (void)loadIcon:(NSObject *)providerData viewController:(UIViewController *)viewController
      completion:(void (^)(UIImage *image))completionHandler {
    // NOTSUPPORTED
}

- (void)delete:(SafeMetaData *)safeMetaData completion:(void (^)(const NSError *))completion {
    // NOTIMPL
}

- (NSArray *)mapToBrowserItems:(NSArray<ODItem *> *)entries {
    NSMutableArray<StorageBrowserItem *> *ret = [[NSMutableArray alloc] init];
    
    for (ODItem *entry in entries) {
        //NSLog(@"Entry: %@", entry);
        //NSLog(@"-------------------------------------------------------------------------------------------------------");
        
        //        if(entry.remoteItem) {
        //            NSLog(@"OneDrive Skipping Remote Item: [%@]", entry.name);
        //            continue;
        //        }
        //
        
        StorageBrowserItem *item = [[StorageBrowserItem alloc] init];
        
        item.providerData = entry;
        item.name = entry.name;
        item.folder = (entry.remoteItem && entry.remoteItem.folder != nil) || entry.folder != nil;
        
        [ret addObject:item];
    }
    
    return ret;
}

- (void)authWrapperWithCompletion:(UIViewController*)viewController completion:(void (^)(BOOL userInteractionRequired, NSError* error))completion {
    ODClient* current = [ODClient loadCurrentClient];
    if (current) {
        self.odClient = current;
        completion(NO, nil);
        return;
    }
    
    if (!viewController) {
        completion (YES, nil);
        return;
    }
    else {
        dispatch_async(dispatch_get_main_queue(), ^{
            [ODClient clientWithCompletion:^(ODClient *client, NSError *error){
                if (!error){
                    self.odClient = client;
                    completion(NO, nil);
                }
                else {
                    NSLog(@"Onedrive error: %@", error);
                    self.odClient = nil;
                    completion(NO, error);
                }
            }];
        });
    }
}

- (void)signout:(void (^)(NSError *error))completion {
    if(!self.odClient) {
        NSLog(@"OneDrive Signout: No Active Session.");
        
        // NB: Necessary so that you can choose a different account.
        
        NSHTTPCookieStorage *cookieStorage = [NSHTTPCookieStorage sharedHTTPCookieStorage];
        for (NSHTTPCookie *each in cookieStorage.cookies) { [cookieStorage deleteCookie:each]; }

        completion(nil);
    }
    else {
        [self.odClient signOutWithCompletion:^(NSError *error) {
            self.odClient = nil;

            // NB: Necessary so that you can choose a different account.

            NSHTTPCookieStorage *cookieStorage = [NSHTTPCookieStorage sharedHTTPCookieStorage];
            for (NSHTTPCookie *each in cookieStorage.cookies) { [cookieStorage deleteCookie:each]; }

            completion(error);
        }];
    }
}

- (BOOL)isSignedIn {
    return self.odClient != nil;
}

@end
