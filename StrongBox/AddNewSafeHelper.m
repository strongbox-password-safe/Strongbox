//
//  AddNewSafeHelper.m
//  Strongbox
//
//  Created by Mark on 05/12/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
//

#import "AddNewSafeHelper.h"
#import "Alerts.h"
#import "KeyFileParser.h"
#import "AppleICloudProvider.h"
#import "Settings.h"
#import "LocalDeviceStorageProvider.h"
#import "YubiManager.h"

const DatabaseFormat kDefaultFormat = kKeePass4;

@implementation AddNewSafeHelper

+ (void)createNewExpressDatabase:(UIViewController*)vc
                            name:(NSString *)name
                        password:(NSString *)password
                      completion:(void (^)(BOOL userCancelled, SafeMetaData* metadata, NSError* error))completion {
    NSError* error;
    DatabaseModel *database = getNewDatabase(password, nil, nil, nil, kDefaultFormat, &error);
    
    if(!database) {
        completion(NO, nil, error);
        return;
    }
    
    BOOL iCloud = Settings.sharedInstance.iCloudOn;
    
    [AddNewSafeHelper createDatabase:vc
                                name:name
                          keyFileUrl:nil
                            database:database
                            provider:iCloud ? AppleICloudProvider.sharedInstance : LocalDeviceStorageProvider.sharedInstance
                        parentFolder:nil
                       yubiKeyConfig:nil
                          completion:completion];
}

+ (void)createNewDatabase:(UIViewController *)vc
                     name:(NSString *)name
                 password:(NSString *)password
               keyFileUrl:(NSURL *)keyFileUrl
       onceOffKeyFileData:(NSData *)onceOffKeyFileData
            yubiKeyConfig:(YubiKeyHardwareConfiguration *)yubiKeyConfig
            storageParams:(nonnull SelectedStorageParameters *)storageParams
                   format:(DatabaseFormat)format
               completion:(nonnull void (^)(BOOL userCancelled, SafeMetaData * _Nullable, NSError * _Nullable))completion {
    NSError* error;
    DatabaseModel *database = getNewDatabase(password, keyFileUrl, onceOffKeyFileData, yubiKeyConfig, format, &error);
    
    if(!database) {
        completion(NO, nil, error);
        return;
    }
    
    [AddNewSafeHelper createDatabase:vc
                                name:name
                          keyFileUrl:keyFileUrl
                            database:database
                            provider:storageParams.provider
                        parentFolder:storageParams.parentFolder
                       yubiKeyConfig:yubiKeyConfig
                          completion:completion];
}

+ (void)createDatabase:(UIViewController*)vc
                  name:(NSString*)name
            keyFileUrl:(NSURL *)keyFileUrl
              database:(DatabaseModel*)database
              provider:(id<SafeStorageProvider>)provider
          parentFolder:(NSObject*)parentFolder
         yubiKeyConfig:(YubiKeyHardwareConfiguration *)yubiKeyConfig
           completion:(void (^)(BOOL userCancelled, SafeMetaData* metadata, NSError* error))completion {
    [database getAsData:^(BOOL userCancelled, NSData * _Nullable data, NSError * _Nullable error) {
        if (userCancelled || data == nil || error) {
            completion(userCancelled, nil, error);
            return;
        }
        
        dispatch_async(dispatch_get_main_queue(), ^(void) { // Saving Has to be done on main thread :(
            [provider create:name
                   extension:database.fileExtension
                        data:data
                parentFolder:parentFolder
              viewController:vc
                  completion:^(SafeMetaData *metadata, NSError *error)
             {
                metadata.keyFileUrl = keyFileUrl;
                metadata.likelyFormat = database.format;
                metadata.yubiKeyConfig = yubiKeyConfig;

                dispatch_async(dispatch_get_main_queue(), ^(void) {
                    completion(NO, metadata, error);
                });
             }];
        });
    }];
}

static DatabaseModel* getNewDatabase(NSString* password,
                                     NSURL* keyFileUrl,
                                     NSData* onceOffKeyFileData,
                                     YubiKeyHardwareConfiguration *yubiConfig,
                                     DatabaseFormat format,
                                     NSError** error) {
    NSData* keyFileDigest = getKeyFileDigest(keyFileUrl, onceOffKeyFileData, format, error);
    if (*error) {
        return nil;
    }
    
    CompositeKeyFactors* ckf;
    if (yubiConfig && yubiConfig.mode != kNoYubiKey) {
        ckf = [CompositeKeyFactors password:password
                              keyFileDigest:keyFileDigest
                                  yubiKeyCR:^(NSData * _Nonnull challenge, YubiKeyCRResponseBlock  _Nonnull completion) {
            #ifndef IS_APP_EXTENSION
            [YubiManager.sharedInstance getResponse:yubiConfig
                                          challenge:challenge
                                         completion:completion];
            #endif
        }];
    }
    else {
        ckf = [CompositeKeyFactors password:password keyFileDigest:keyFileDigest];
    }
    
    return [[DatabaseModel alloc] initNew:ckf format:format];
}

NSData* getKeyFileDigest(NSURL* keyFileUrl, NSData* onceOffKeyFileData, DatabaseFormat format, NSError** error) {
    NSData* keyFileData = getKeyFileData(keyFileUrl, onceOffKeyFileData, error);
    
    NSData *keyFileDigest = keyFileData ? [KeyFileParser getKeyFileDigestFromFileData:keyFileData checkForXml:format != kKeePass1] : nil;

    return keyFileDigest;
}

NSData* getKeyFileData(NSURL* keyFileUrl, NSData* onceOffKeyFileData, NSError** error) {
    NSData* keyFileData = nil;
    if (keyFileUrl) {
        keyFileData = [NSData dataWithContentsOfURL:keyFileUrl options:kNilOptions error:error];
    }
    else if (onceOffKeyFileData) {
        keyFileData = onceOffKeyFileData;
    }
    
    return keyFileData;
}

@end
