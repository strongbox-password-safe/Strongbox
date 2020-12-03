//
//  OneDriveForBusinessStorageProvider.m
//  Strongbox-iOS
//
//  Created by Mark on 29/09/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
//

#import "OneDriveForBusinessStorageProvider.h"
#import "Utils.h"
#import <SVProgressHUD/SVProgressHUD.h>
#import "OneDriveSDK.h"

@interface OneDriveForBusinessStorageProvider()

@property (nonatomic) ODClient *odClient;

@end

static NSString *kApplicationId = @"8c10a31a-0f4b-4931-a450-c2959b0a7169";
static NSString *kRedirectUri = @"https:

@implementation OneDriveForBusinessStorageProvider

+ (instancetype)sharedInstance {
    static OneDriveForBusinessStorageProvider *sharedInstance = nil;
    static dispatch_once_t onceToken;
    
    dispatch_once(&onceToken, ^{
        sharedInstance = [[OneDriveForBusinessStorageProvider alloc] init];
    });
    return sharedInstance;
}

- (instancetype)init {
    if (self = [super init]) {
        _displayName = @"OneDrive For Business";
        _icon = @"one-drive-icon-only-32x32";
        _storageId = kOneDriveForBusiness;
        _cloudBased = YES;
        _providesIcons = NO;
        _browsableNew = YES;
        _browsableExisting = YES;
        _rootFolderOnly = NO;
        
        [ODClient setActiveDirectoryAppId:kApplicationId redirectURL:kRedirectUri];
        
        

        ODClient* blah = [ODClient loadCurrentClient];

        if(blah) {
            [blah signOutWithCompletion:^(NSError *error) {
                NSLog(@"Signed Out");
                NSHTTPCookieStorage *cookieStorage = [NSHTTPCookieStorage sharedHTTPCookieStorage];
                for (NSHTTPCookie *each in cookieStorage.cookies) {
                    NSLog(@"%@", each);
                    [cookieStorage deleteCookie:each]; }
            }];
        }
        else {
            NSHTTPCookieStorage *cookieStorage = [NSHTTPCookieStorage sharedHTTPCookieStorage];
            for (NSHTTPCookie *each in cookieStorage.cookies) { NSLog(@"%@", each); [cookieStorage deleteCookie:each]; }
        }
        
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
    [self authWrapperWithCompletion:^(NSError *error) {
        [SVProgressHUD show];
        
        NSString *desiredFilename = [NSString stringWithFormat:@"%@-strongbox.dat", nickName];
        
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

- (void)      read:(SafeMetaData *)safeMetaData
    viewController:(UIViewController *)viewController
        completion:(void (^)(NSData *data, NSError *error))completion {
    [self authWrapperWithCompletion:^(NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [SVProgressHUD showWithStatus:@"Locating..."];
        });
        
        [self providerDataFromMetadata:safeMetaData completion:^(ODItem *item, NSError *error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [SVProgressHUD dismiss];
            });
            
            if(error || !item) {
                if(!item) {
                    error = [Utils createNSError:@"Could not locate the safe file. Has it been renamed or moved?" errorCode:45];
                }
                
                NSLog(@"OneDrive Read: %@", error);
                completion(nil, error);
                return;
            }
            
            [self readWithProviderData:item viewController:viewController completion:completion];
        }];
    }];
}

- (void)readWithProviderData:(NSObject *)providerData
              viewController:(UIViewController *)viewController
                  completion:(void (^)(NSData *data, NSError *error))completion {
    [self authWrapperWithCompletion:^(NSError *error) {
        ODItem* item = (ODItem*)providerData;
        
        
        
        ODItemContentRequest *request;
        
        request = [[[self.odClient drives:item.parentReference.driveId] items:item.id] contentRequest];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [SVProgressHUD showWithStatus:@"Reading..."];
        });
        
        [request downloadWithCompletion:^(NSURL *filePath, NSURLResponse *urlResponse, NSError *error){
            dispatch_async(dispatch_get_main_queue(), ^{
                [SVProgressHUD dismiss];
            });
            
            if(error) {
                NSLog(@"%@", error);
                completion(nil, error);
                return;
            }
            
            
            
            
            
            
            
            
            
            NSData *data = [[NSFileManager defaultManager] contentsAtPath:filePath.path];
            
            NSLog(@"OneDrive Read %lu bytes.", (unsigned long)data.length);
            
            completion(data, nil);
        }];
    }];
}

- (void)update:(SafeMetaData *)safeMetaData
          data:(NSData *)data
    completion:(void (^)(NSError *error))completion {
    [self authWrapperWithCompletion:^(NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [SVProgressHUD showWithStatus:@"Locating..."];
        });
        
        [self providerDataFromMetadata:safeMetaData completion:^(ODItem *item, NSError *error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [SVProgressHUD dismiss];
            });
            
            if(error || !item) {
                if(!item) {
                    error = [Utils createNSError:@"Could not locate the safe file. Has it been renamed or moved?" errorCode:45];
                }
                
                NSLog(@"OneDrive Read: %@", error);
                completion(error);
                return;
            }
            
            ODItemContentRequest *request;
            request = [[[self.odClient drives:item.parentReference.driveId] items:item.id] contentRequest];
            
            dispatch_async(dispatch_get_main_queue(), ^{
                [SVProgressHUD showWithStatus:@"Updating..."];
            });
            
            [request uploadFromData:data completion:^(ODItem *response, NSError *error) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [SVProgressHUD dismiss];
                });
                
                completion(error);
            }];
        }];
    }];
}

- (void)      list:(NSObject *)parentFolder
    viewController:(UIViewController *)viewController
        completion:(void (^)(NSArray<StorageBrowserItem *> *items, NSError *error))completion {
    [self authWrapperWithCompletion:^(NSError *error) {
        if(error) {
            completion(nil, error);
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
           completion:(void (^)(NSArray<StorageBrowserItem *> *items, NSError *error))completion
{
    [request getWithCompletion:^(ODCollection *response, ODChildrenCollectionRequest *nr, NSError *error) {
        if(error) {
            NSLog(@"%@", error);
            completion(nil, error);
            return;
        }
        
        NSArray* chunk = [self mapToBrowserItems:response.value];
        [existingItems addObjectsFromArray:chunk];
        
        if(nr) {
            [self listRecursive:nr error:error existingItems:existingItems completion:completion];
        }
        else {
            NSLog(@"Got all items: [%lu]", (unsigned long)existingItems.count);
            completion([NSArray arrayWithArray:existingItems], nil);
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
    
    NSLog(@"Searching for drive:[%@] parent:[%@] name:[%@]", driveId, parentFolderId, metadata.fileName);
    
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
            if([item.name isEqualToString:target]) {
                NSLog(@"Found!");
                foundItem = item;
                break;
            }
        }
        
        if(!foundItem && nr) {
            NSLog(@"Recursing...");
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

- (void)delete:(SafeMetaData *)safeMetaData completion:(void (^)(NSError *))completion {
    
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

- (void)authWrapperWithCompletion:(void (^)(NSError* error))completion {
    [ODClient clientWithCompletion:^(ODClient *client, NSError *error){
        if (!error){
            self.odClient = client;
            completion(nil);
        }
        else {
            NSLog(@"Onedrive error: %@", error);
            self.odClient = nil;
            completion(error);
        }
    }];
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
