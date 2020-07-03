//
//  DuressDummyStorageProvider.m
//  Strongbox
//
//  Created by Mark on 16/01/2019.
//  Copyright © 2019 Mark McGuill. All rights reserved.
//

#import "DuressDummyStorageProvider.h"
#import "SharedAppAndAutoFillSettings.h"

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

- (void)create:(NSString *)nickName extension:(NSString *)extension data:(NSData *)data parentFolder:(NSObject *)parentFolder viewController:(UIViewController *)viewController completion:(void (^)(SafeMetaData *, const NSError *))completion {
    // NOTIMPL
}

- (void)delete:(SafeMetaData *)safeMetaData completion:(void (^)(const NSError *))completion {
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

- (void)list:(NSObject *)parentFolder viewController:(UIViewController *)viewController completion:(void (^)(BOOL, NSArray<StorageBrowserItem *> *, const NSError *))completion {
    // NOTIMPL
}

- (void)loadIcon:(NSObject *)providerData viewController:(UIViewController *)viewController completion:(void (^)(UIImage *))completionHandler {
    // NOTIMPL
}

- (void)readLegacy:(nonnull SafeMetaData *)safeMetaData viewController:(nonnull UIViewController *)viewController isAutoFill:(BOOL)isAutoFill completion:(nonnull void (^)(NSData * _Nullable, const NSError * _Nullable))completion {
    [self read:safeMetaData viewController:viewController completion:completion];
}

- (void)read:(nonnull SafeMetaData *)safeMetaData viewController:(UIViewController *)viewController completion:(nonnull void (^)(NSData * _Nullable, const NSError * _Nullable))completion {
    [self readNonInteractive:safeMetaData completion:completion];
}

- (void)readWithProviderData:(NSObject *)providerData
              viewController:(UIViewController *)viewController
                  completion:(void (^)(NSData *, const NSError *))completionHandler {
    [self readNonInteractive:(SafeMetaData*)providerData completion:completionHandler];
}

- (void)readNonInteractive:(nonnull SafeMetaData *)safeMetaData completion:(nonnull void (^)(NSData * _Nullable, const NSError * _Nullable))completion {
    [self getData:^(NSData *data) {
        completion(data, nil);
    }];
}

- (void)update:(SafeMetaData *)safeMetaData data:(NSData *)data isAutoFill:(BOOL)isAutoFill completion:(void (^)(NSError * _Nullable))completion {
    [self setData:data];
    completion(nil);
}

- (void)database:(void(^)(DatabaseModel* model))completion {
    [self getData:^(NSData *data) {
        CompositeKeyFactors *cpf = [CompositeKeyFactors password:@"1234"];
        
        DatabaseModelConfig* modelConfig = [DatabaseModelConfig withPasswordConfig:SharedAppAndAutoFillSettings.sharedInstance.passwordGenerationConfig];
        
        [DatabaseModel fromLegacyData:data
                                  ckf:cpf
                               config:modelConfig
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
    NSData* data = SharedAppAndAutoFillSettings.sharedInstance.duressDummyData;    
    if(!data) {
        CompositeKeyFactors *cpf = [CompositeKeyFactors password:@"1234"];
        DatabaseModelConfig* config = [DatabaseModelConfig withPasswordConfig:SharedAppAndAutoFillSettings.sharedInstance.passwordGenerationConfig];
        DatabaseModel* model = [[DatabaseModel alloc] initNew:cpf format:kKeePass config:config];
        
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
    SharedAppAndAutoFillSettings.sharedInstance.duressDummyData = data;
}

@end
