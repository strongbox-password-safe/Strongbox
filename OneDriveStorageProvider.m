//
//  OneDriveStorageProvider.m
//  Strongbox-iOS
//
//  Created by Mark on 25/07/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
//

#import "OneDriveStorageProvider.h"
#import "Utils.h"
#import <SVProgressHUD/SVProgressHUD.h>
#import "OneDriveSDK/OneDriveSDK.h"

@interface OneDriveStorageProvider()

@property (nonatomic) ODClient *odClient;

@end

static NSString *kApplicationId = @"708058b4-71de-4c54-ae7f-0e6f5872e953";

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
        _displayName = @"OneDrive";
        _icon = @"one-drive-icon-only-32x32";
        _storageId = kOneDrive;
        _cloudBased = YES;
        _providesIcons = NO;
        _browsableNew = YES;
        _browsableExisting = YES;

        [ODClient setMicrosoftAccountAppId:kApplicationId scopes:@[@"onedrive.readwrite"]];

        
        
        NSArray *foo = [[ODAccountStore defaultAccountStore] loadAccounts];
        for (NSObject *each in foo) {
            NSLog(@"Account: %@", each);
        }
        
        NSHTTPCookieStorage *cookieStorage = [NSHTTPCookieStorage sharedHTTPCookieStorage];
        for (NSHTTPCookie *each in cookieStorage.cookies) { [cookieStorage deleteCookie:each]; }
        
        
        NSArray* clients = [ODClient loadClients];
        
        for (NSObject *client in clients) {
            NSLog(@"Client %@", client);
        }

        ////ODClient applic
        //[ODClient setCurrentClient:nil];
        self.odClient = nil;
        
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

}

- (void)      read:(SafeMetaData *)safeMetaData
    viewController:(UIViewController *)viewController
        completion:(void (^)(NSData *data, NSError *error))completion {
}

- (void)readWithProviderData:(NSObject *)providerData
              viewController:(UIViewController *)viewController
                  completion:(void (^)(NSData *data, NSError *error))completion {
}

- (void)update:(SafeMetaData *)safeMetaData
          data:(NSData *)data
    completion:(void (^)(NSError *error))completion {
}

- (void)      list:(NSObject *)parentFolder
    viewController:(UIViewController *)viewController
        completion:(void (^)(NSArray<StorageBrowserItem *> *items, NSError *error))completion {
    [self authWrapperWithCompletion:^(NSError *error) {
        if(error) {
            completion(nil, error);
            return;
        }
        
        NSString *parentItemId = parentFolder == nil ? @"root" : ((ODItem*)parentFolder).id;
        
        ODChildrenCollectionRequest *request = [[[[self.odClient drive] items:parentItemId] children] request];
        
        [self listRecursive:request error:error existingItems:[NSMutableArray array] completion:completion];
    }];
}

- (void)listRecursive:(ODChildrenCollectionRequest *)request
      error:(NSError *)error
      existingItems:(NSMutableArray<StorageBrowserItem*>*)existingItems
 completion:(void (^)(NSArray<StorageBrowserItem *> *items, NSError *error))completion
{
    [request getWithCompletion:^(ODCollection *response, ODChildrenCollectionRequest *nr, NSError *error) {
        // TODO: Shared With Me files
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
    return nil;
}

- (void)loadIcon:(NSObject *)providerData viewController:(UIViewController *)viewController
      completion:(void (^)(UIImage *image))completionHandler {
    // NOTSUPPORTED
}

- (void)delete:(SafeMetaData *)safeMetaData completion:(void (^)(NSError *))completion {
    // NOTIMPL
}

- (NSArray *)mapToBrowserItems:(NSArray<ODItem *> *)entries {
    NSMutableArray<StorageBrowserItem *> *ret = [[NSMutableArray alloc] init];
    
    for (ODItem *entry in entries) {
        StorageBrowserItem *item = [[StorageBrowserItem alloc] init];
        
        item.providerData = entry;
        item.name = entry.name;
        item.folder = entry.folder != nil;
        
        [ret addObject:item];
    }
    
    return ret;
}

- (void)authWrapperWithCompletion:(void (^)(NSError* error))completion {
    if(!self.odClient) {
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
    else {
        completion(nil);
    }
}

- (void)signout:(void (^)(NSError *error))completion {
    if(!self.odClient) {
        NSLog(@"OneDrive Signout: No Active Session.");
        completion(nil);
    }
    else {
        [self.odClient signOutWithCompletion:^(NSError *error) {
            self.odClient = nil;
            completion(error);
        }];
    }
}

- (BOOL)isSignedIn {
    return self.odClient != nil;
}

@end
