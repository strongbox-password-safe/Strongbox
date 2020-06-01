//
//  DuressDummyStorageProvider.m
//  Strongbox
//
//  Created by Mark on 16/01/2019.
//  Copyright © 2019 Mark McGuill. All rights reserved.
//

#import "DuressDummyStorageProvider.h"
#import "Settings.h"

@implementation DuressDummyStorageProvider

+ (instancetype)sharedInstance {
    static DuressDummyStorageProvider *sharedInstance = nil;
    static dispatch_once_t onceToken;
    
    dispatch_once(&onceToken, ^{
        sharedInstance = [[DuressDummyStorageProvider alloc] init];
    });
    return sharedInstance;
}

- (instancetype)init {
    if (self = [super init]) {
        _displayName = @"";
        _icon = @"product32";
        _storageId = kDuressDummy;
        _allowOfflineCache = NO;
        _providesIcons = NO;
        _browsableNew = NO;
        _browsableExisting = NO;
        _rootFolderOnly = YES;
        _immediatelyOfferCacheIfOffline = NO;
        
        return self;
    }
    else {
        return nil;
    }
}


- (void)create:(NSString *)nickName extension:(NSString *)extension data:(NSData *)data parentFolder:(NSObject *)parentFolder viewController:(UIViewController *)viewController completion:(void (^)(SafeMetaData *, NSError *))completion {
    // NOTIMPL
}

- (void)delete:(SafeMetaData *)safeMetaData completion:(void (^)(NSError *))completion {
    // NOTIMPL
}

- (SafeMetaData *)getSafeMetaData:(NSString *)nickName providerData:(NSObject *)providerData {
    // NOTIMPL
    return nil;
}

- (SafeMetaData *)getSafeMetaData:(NSString *)nickName filename:(NSString*)filename fileIdentifier:(NSString*)fileIdentifier {
    SafeMetaData* meta = [[SafeMetaData alloc] initWithNickName:nickName storageProvider:kDuressDummy fileName:filename fileIdentifier:fileIdentifier];
    
    meta.autoFillEnabled = NO;
    
    return meta;
}

- (void)list:(NSObject *)parentFolder viewController:(UIViewController *)viewController completion:(void (^)(BOOL, NSArray<StorageBrowserItem *> *, NSError *))completion {
    // NOTIMPL
}

- (void)loadIcon:(NSObject *)providerData viewController:(UIViewController *)viewController completion:(void (^)(UIImage *))completionHandler {
    // NOTIMPL
}

- (void)read:(SafeMetaData *)safeMetaData
viewController:(UIViewController *)viewController
  isAutoFill:(BOOL)isAutoFill
  completion:(void (^)(NSData * _Nonnull, NSError * _Nonnull))completion {
    return [self readWithProviderData:nil viewController:viewController completion:completion];
}

- (void)readWithProviderData:(NSObject *)providerData
              viewController:(UIViewController *)viewController
                  completion:(void (^)(NSData *, NSError *))completionHandler {
    [self getData:^(NSData *data) {
        completionHandler(data, nil);
    }];
}

- (void)update:(SafeMetaData *)safeMetaData data:(NSData *)data isAutoFill:(BOOL)isAutoFill completion:(void (^)(NSError * _Nullable))completion {
    [self setData:data];
    completion(nil);
}

- (void)database:(void(^)(DatabaseModel* model))completion {
    [self getData:^(NSData *data) {
        CompositeKeyFactors *cpf = [CompositeKeyFactors password:@"1234"];
        
        [DatabaseModel fromData:data
                            ckf:cpf
                     completion:^(BOOL userCancelled, DatabaseModel * model, NSError * error) {
            if(!model || error != nil) {
                // For some reason we can't open the duress database... reset it - probably because someone changed the password
                [self setData:nil];
                [self database:completion];
            }
            else {
                completion(model);
            }
        }];
    }];
}

- (void)getData:(void(^)(NSData* data))completion {
    NSUserDefaults* defaults = [Settings.sharedInstance getSharedAppGroupDefaults]; // FUTURE: Not an ideal place for data storage
    NSData* data = [defaults objectForKey:@"dd-safe"];
    if(!data) {
        CompositeKeyFactors *cpf = [CompositeKeyFactors password:@"1234"];
        DatabaseModel* model = [[DatabaseModel alloc] initNew:cpf format:kKeePass];
        [model getAsData:^(BOOL userCancelled, NSData * _Nullable data, NSError * _Nullable error) {
            [self setData:data];
            completion(data);
        }];
    }
    else {
        completion(data);
    }
}

- (void)setData:(NSData*)data {
    NSUserDefaults* defaults = [Settings.sharedInstance getSharedAppGroupDefaults];
    [defaults setObject:data forKey:@"dd-safe"];
    [defaults synchronize];
}

@end
