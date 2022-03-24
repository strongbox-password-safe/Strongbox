//
//  OneDriveStorageProvider.m
//  Strongbox-iOS
//
//  Created by Mark on 25/07/2018.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import "OneDriveStorageProvider.h"
#import "Utils.h"
#import "SVProgressHUD.h"
#import "OneDriveSDK.h"
#import "NSDate+Extensions.h"

@interface OneDriveStorageProvider ()

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

- (void)getModDate:(nonnull METADATA_PTR)safeMetaData completion:(nonnull StorageProviderGetModDateCompletionBlock)completion {
    
}

- (instancetype)init {
    if (self = [super init]) {
        _storageId = kOneDrive;
        _providesIcons = NO;
        _browsableNew = YES;
        _browsableExisting = YES;
        _rootFolderOnly = NO;
        _defaultForImmediatelyOfferOfflineCache = YES; 
        _supportsConcurrentRequests = NO; 
        _privacyOptInRequired = YES;
        
        [ODClient setMicrosoftAccountAppId:kApplicationId scopes:@[@"onedrive.readwrite", @"offline_access"]];
        
        
        
        
        
        
        static NSString * const kBusinessApplicationId = @"8c10a31a-0f4b-4931-a450-c2959b0a7169";
        static NSString * const kBusinessRedirectUri = @"https:

        
        
        [ODClient setActiveDirectoryAppId:kBusinessApplicationId
                               resourceId:@"https:
                              apiEndpoint:@"https:
                              redirectURL:kBusinessRedirectUri];
        





        
        















        
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
        completion:(void (^)(DatabasePreferences *metadata, const NSError *error))completion {
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
                
                
                DatabasePreferences *metadata = [self getDatabasePreferences:nickName
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

- (void)pullDatabase:(DatabasePreferences *)safeMetaData interactiveVC:(UIViewController *)viewController options:(StorageProviderReadOptions *)options completion:(StorageProviderReadCompletionBlock)completion {
    [self authWrapperWithCompletion:viewController completion:^(BOOL userInteractionRequired, NSError *error) {
        if(error) {
            completion(kReadResultError, nil, nil, error);
            [self signout:^(NSError *error) { }];  
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
                [self signout:^(NSError *error) { }];  
                return;
            }
            
            [self readWithProviderData:item viewController:viewController options:options completion:completion];
        }];
    }];
}

- (void)readWithProviderData:(NSObject *)providerData viewController:(UIViewController *)viewController options:(StorageProviderReadOptions *)options completion:(StorageProviderReadCompletionBlock)completion {
    [self authWrapperWithCompletion:viewController completion:^(BOOL userInteractionRequired, NSError *error) {
        if(error) {
            completion(kReadResultError, nil, nil, error);
            [self signout:^(NSError *error) { }];  
            return;
        }
                      
        if (userInteractionRequired) {
            completion(kReadResultBackgroundReadButUserInteractionRequired, nil, nil, nil);
            return;
        }

        ODItem* item = (ODItem*)providerData;
        


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
                [self signout:^(NSError *error) { }];  
                return;
            }
            
            
            
            
            
            
            
    
            
            NSData *data = [[NSFileManager defaultManager] contentsAtPath:filePath.path];
            
            
            
            completion(kReadResultSuccess, data, item.lastModifiedDateTime, nil);
        }];
    }];
}

- (void)pushDatabase:(DatabasePreferences *)safeMetaData interactiveVC:(UIViewController *)viewController data:(NSData *)data completion:(StorageProviderUpdateCompletionBlock)completion {
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

            [self upload:safeMetaData item:item interactiveVC:viewController data:data completion:completion];
        }];
    }];
}

- (void)upload:(DatabasePreferences *)safeMetaData item:(ODItem*)item interactiveVC:(UIViewController *)viewController data:(NSData *)data completion:(StorageProviderUpdateCompletionBlock)completion {
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
}

- (void)      list:(NSObject *)parentFolder
    viewController:(UIViewController *)viewController
        completion:(void (^)(BOOL, NSArray<StorageBrowserItem *> *, const NSError *))completion {
    [self authWrapperWithCompletion:viewController completion:^(BOOL userInteractionRequired, NSError *error) {
        if(error) {
            completion(error.code == ODAuthCanceled, nil, error);
            if (error.code != ODAuthCanceled) {
                [self signout:^(NSError *error) { }];  
            }
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

- (DatabasePreferences *)getDatabasePreferences:(NSString *)nickName providerData:(NSObject *)providerData {
    ODItem *file = (ODItem *)providerData;
   
    NSDictionary* dp = [NSDictionary dictionaryWithObjectsAndKeys:file.parentReference.driveId, @"driveId", file.parentReference.id, @"parentFolderId", nil];
    
    NSError* error;
    NSData* data = [NSJSONSerialization dataWithJSONObject:dp options:0 error:&error];
    
    if(error) {
        NSLog(@"%@", error);
        return nil;
    }
   
    NSString *json = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    
    NSString *parent = json;
    
    return [DatabasePreferences templateDummyWithNickName:nickName
                                          storageProvider:self.storageId
                                                 fileName:file.name
                                           fileIdentifier:parent];
}

- (void)providerDataFromMetadata:(DatabasePreferences*)metadata completion:(void(^)(ODItem* item, NSError* error))completion {
    NSData* data = [metadata.fileIdentifier dataUsingEncoding:NSUTF8StringEncoding];
    
    NSError *error;
    NSDictionary* dictionary = (NSDictionary*)[NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
    
    if(error) {
        completion(nil, error);
        return;
    }
    
    NSString* driveId = [dictionary objectForKey:@"driveId"];
    NSString* parentFolderId = [dictionary objectForKey:@"parentFolderId"];
    
    
    
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
    
}

- (void)delete:(DatabasePreferences *)safeMetaData completion:(void (^)(const NSError *))completion {
    
}

- (NSArray *)mapToBrowserItems:(NSArray<ODItem *> *)entries {
    NSMutableArray<StorageBrowserItem *> *ret = [[NSMutableArray alloc] init];
    
    for (ODItem *entry in entries) {
        
        
        
        
        
        
        
        
        
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
        
        
        
        NSHTTPCookieStorage *cookieStorage = [NSHTTPCookieStorage sharedHTTPCookieStorage];
        for (NSHTTPCookie *each in cookieStorage.cookies) { [cookieStorage deleteCookie:each]; }

        completion(nil);
    }
    else {
        [self.odClient signOutWithCompletion:^(NSError *error) {
            self.odClient = nil;

            

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
