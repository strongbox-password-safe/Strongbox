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
#import "BookmarksHelper.h"
#import "SharedAppAndAutoFillSettings.h"
#import "OpenSafeSequenceHelper.h"
#import "SVProgressHUD.h"

const DatabaseFormat kDefaultFormat = kKeePass4;

@implementation AddNewSafeHelper

+ (void)createNewExpressDatabase:(UIViewController*)vc
                            name:(NSString *)name
                        password:(NSString *)password
                      completion:(void (^)(BOOL userCancelled, SafeMetaData* metadata, NSData* initialSnapshot, NSError* error))completion {
    NSError* error;
    DatabaseModel *database = getNewDatabase(password, nil, nil, nil, kDefaultFormat, &error);
    
    if(!database) {
        completion(NO, nil, nil, error);
        return;
    }
    
    BOOL iCloud = SharedAppAndAutoFillSettings.sharedInstance.iCloudOn;
    
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
               completion:(nonnull void (^)(BOOL userCancelled, SafeMetaData * _Nullable, NSData* initialSnapshot, NSError * _Nullable))completion {
    NSError* error;
    DatabaseModel *database = getNewDatabase(password, keyFileUrl, onceOffKeyFileData, yubiKeyConfig, format, &error);
    
    if(!database) {
        completion(NO, nil, nil, error);
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
           completion:(void (^)(BOOL userCancelled, SafeMetaData* metadata, NSData* initialSnapshot, NSError* error))completion {
    dispatch_async(dispatch_get_main_queue(), ^(void) { // Saving Has to be done on main thread :(
        [SVProgressHUD showWithStatus:NSLocalizedString(@"generic_encrypting", @"Encrypting")];
    });
                   
    dispatch_async(dispatch_get_global_queue(0L, DISPATCH_QUEUE_PRIORITY_DEFAULT), ^{
        [database getAsData:^(BOOL userCancelled, NSData * _Nullable data, NSError * _Nullable error) {
            if (userCancelled || data == nil || error) {
                completion(userCancelled, nil, nil, error);
                return;
            }
            
            dispatch_async(dispatch_get_main_queue(), ^(void) { // Saving Has to be done on main thread :(
                [SVProgressHUD dismiss];
                
                [provider create:name
                       extension:database.fileExtension
                            data:data
                    parentFolder:parentFolder
                  viewController:vc
                      completion:^(SafeMetaData *metadata, NSError *error)
                 {
                    if (keyFileUrl) {
                        NSError* error = nil;
                        NSString* bookmark = [BookmarksHelper getBookmarkFromUrl:keyFileUrl readOnly:YES error:&error];
                        if (bookmark && !error) {
                            metadata.keyFileBookmark = bookmark;
                        }
                        else {
                            metadata.keyFileBookmark = nil;
                            NSLog(@"WARNWARN: Could not get Key File book for URL: [%@]. Error = [%@]", keyFileUrl, error);
                        }
                        
                        metadata.keyFileUrl = keyFileUrl;
                    }
                    else {
                        metadata.keyFileBookmark = nil;
                        metadata.keyFileUrl = nil;
                    }

                    metadata.likelyFormat = database.format;
                    metadata.yubiKeyConfig = yubiKeyConfig;

                    dispatch_async(dispatch_get_main_queue(), ^(void) {
                        completion(NO, metadata, data, error);
                    });
                 }];
            });
        }];
    });
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
    
    return [[DatabaseModel alloc] initNew:ckf
                                   format:format
                                   config:[DatabaseModelConfig withPasswordConfig:SharedAppAndAutoFillSettings.sharedInstance.passwordGenerationConfig]];
}

@end
