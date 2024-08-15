//
//  AddNewSafeHelper.m
//  Strongbox
//
//  Created by Mark on 05/12/2018.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import "AddNewSafeHelper.h"
#import "Alerts.h"
#import "KeyFileManagement.h"
#import "LocalDeviceStorageProvider.h"
#import "YubiManager.h"
#import "BookmarksHelper.h"
#import "AppPreferences.h"
#import "SVProgressHUD.h"
#import "Serializator.h"
#import "SampleItemsGenerator.h"
#import "Strongbox-Swift.h"

const DatabaseFormat kDefaultFormat = kKeePass4;

@implementation AddNewSafeHelper 

+ (void)createNewExpressDatabase:(UIViewController*)vc
                            name:(NSString *)name
                        password:(NSString *)password
                      completion:(void (^)(BOOL userCancelled, DatabasePreferences* metadata, NSData* initialSnapshot, NSError* error))completion  {
    [AddNewSafeHelper createNewExpressDatabase:vc name:name password:password forceLocal:NO completion:completion];
}

+ (void)createNewExpressDatabase:(UIViewController*)vc
                            name:(NSString *)name
                        password:(NSString *)password
                      forceLocal:(BOOL)forceLocal
                      completion:(void (^)(BOOL userCancelled, DatabasePreferences* metadata, NSData* initialSnapshot, NSError* error))completion {
    NSError* error;
    DatabaseModel *database = getNewDatabase(password, nil, nil, nil, nil, kDefaultFormat, &error);
    
    if(!database) {
        completion(NO, nil, nil, error);
        return;
    }
    
    [AddNewSafeHelper createNewExpressDatabase:vc name:name model:database forceLocal:forceLocal completion:completion];
}

+ (void)createNewExpressDatabase:(UIViewController *)vc
                            name:(NSString *)name
                           model:(DatabaseModel *)model
                      completion:(void (^)(BOOL, DatabasePreferences * _Nonnull, NSData * _Nonnull, NSError * _Nonnull))completion {
    [AddNewSafeHelper createNewExpressDatabase:vc name:name model:model forceLocal:NO completion:completion];
}

+ (void)createNewExpressDatabase:(UIViewController*)vc
                            name:(NSString *)name
                           model:(DatabaseModel *)model
                      forceLocal:(BOOL)forceLocal
                      completion:(void (^)(BOOL userCancelled, DatabasePreferences* metadata, NSData* initialSnapshot, NSError* error))completion {
    
#ifndef NO_NETWORKING
    BOOL useCloudKitForStorage = !forceLocal && !AppPreferences.sharedInstance.disableNetworkBasedFeatures && CloudKitDatabasesInteractor.shared.fastIsAvailable;

    id<SafeStorageProvider> provider = useCloudKitForStorage ? CloudKitStorageProvider.sharedInstance : LocalDeviceStorageProvider.sharedInstance;
#else
    id<SafeStorageProvider> provider = LocalDeviceStorageProvider.sharedInstance;
#endif
    
    [AddNewSafeHelper createDatabase:vc
                                name:name
                     keyFileBookmark:nil
                     keyFileFileName:nil
                            database:model
                            provider:provider
                        parentFolder:nil
                       yubiKeyConfig:nil
                          completion:completion];
}

+ (void)createNewDatabase:(UIViewController *)vc
                     name:(NSString *)name
                 password:(NSString *)password
          keyFileBookmark:(NSString *)keyFileBookmark
          keyFileFileName:(NSString *)keyFileFileName
       onceOffKeyFileData:(NSData *)onceOffKeyFileData
            yubiKeyConfig:(YubiKeyHardwareConfiguration *)yubiKeyConfig
            storageParams:(SelectedStorageParameters *)storageParams
                   format:(DatabaseFormat)format
               completion:(nonnull void (^)(BOOL, DatabasePreferences * _Nullable, NSData * _Nullable, NSError * _Nullable))completion {
    NSError* error;
    DatabaseModel *database = getNewDatabase(password, keyFileBookmark, keyFileFileName, onceOffKeyFileData, yubiKeyConfig, format, &error);
    
    if(!database) {
        completion(NO, nil, nil, error);
        return;
    }
    
    [AddNewSafeHelper createDatabase:vc
                                name:name
                     keyFileBookmark:keyFileBookmark
                     keyFileFileName:keyFileFileName
                            database:database
                            provider:storageParams.provider
                        parentFolder:storageParams.parentFolder
                       yubiKeyConfig:yubiKeyConfig
                          completion:completion];
}

+ (void)createDatabase:(UIViewController*)vc
                  name:(NSString*)name
       keyFileBookmark:(NSString *)keyFileBookmark
       keyFileFileName:(NSString *)keyFileFileName
              database:(DatabaseModel*)database
              provider:(id<SafeStorageProvider>)provider
          parentFolder:(NSObject*)parentFolder
         yubiKeyConfig:(YubiKeyHardwareConfiguration *)yubiKeyConfig
           completion:(void (^)(BOOL userCancelled, DatabasePreferences* metadata, NSData* initialSnapshot, NSError* error))completion {
    dispatch_async(dispatch_get_main_queue(), ^(void) { 
        [SVProgressHUD showWithStatus:NSLocalizedString(@"generic_encrypting", @"Encrypting")];
    });
                  
    DatabaseFormat format = database.originalFormat;
    
    dispatch_async(dispatch_get_global_queue(0L, DISPATCH_QUEUE_PRIORITY_DEFAULT), ^{
        NSOutputStream* outputStream = [NSOutputStream outputStreamToMemory]; 
        [outputStream open];

        [Serializator getAsData:database format:format outputStream:outputStream completion:^(BOOL userCancelled, NSString * _Nullable debugXml, NSError * _Nullable error) {
            if (userCancelled || error) {
                completion(userCancelled, nil, nil, error);
                return;
            }
            
            [outputStream close];
            NSData* data = [outputStream propertyForKey:NSStreamDataWrittenToMemoryStreamKey];

            dispatch_async(dispatch_get_main_queue(), ^(void) { 
                [SVProgressHUD dismiss];

                [SVProgressHUD showWithStatus:NSLocalizedString(@"generic_saving_ellipsis", @"Saving...")];
                
                NSString* filename = [NSString stringWithFormat:@"%@.%@", name, [Serializator getDefaultFileExtensionForFormat:format]];
                                
                [provider create:name
                        fileName:filename
                            data:data
                    parentFolder:parentFolder
                  viewController:vc
                      completion:^(DatabasePreferences *metadata, NSError *error) {
                    [metadata setKeyFile:keyFileBookmark keyFileFileName:keyFileFileName];
                    metadata.likelyFormat = format;
                    metadata.nextGenPrimaryYubiKeyConfig = yubiKeyConfig;

                    dispatch_async(dispatch_get_main_queue(), ^(void) {
                        [SVProgressHUD dismiss];
                        completion(NO, metadata, data, error);
                    });
                 }];
            });
        }];
    });
}

static DatabaseModel* getNewDatabase(NSString* password,
                                     NSString* keyFileBookmark,
                                     NSString* keyFileFileName,
                                     NSData* onceOffKeyFileData,
                                     YubiKeyHardwareConfiguration *yubiConfig,
                                     DatabaseFormat format,
                                     NSError** error) {
    NSData* keyFileDigest = nil;
    if ( keyFileBookmark || keyFileFileName || onceOffKeyFileData ) {
        keyFileDigest = [KeyFileManagement getDigestFromSources:keyFileBookmark
                                            keyFileFileName:keyFileFileName
                                         onceOffKeyFileData:onceOffKeyFileData
                                                     format:format
                                                      error:error];
    
        if ( *error ) {
            return nil;
        }
    }
    
    CompositeKeyFactors* ckf;
    if ( yubiConfig && yubiConfig.mode != kNoYubiKey ) {
        ckf = [CompositeKeyFactors password:password
                              keyFileDigest:keyFileDigest
                                  yubiKeyCR:^(NSData * _Nonnull challenge, YubiKeyCRResponseBlock  _Nonnull completion) {
            [YubiManager.sharedInstance getResponse:yubiConfig challenge:challenge completion:completion];
        }];
    }
    else {
        ckf = [CompositeKeyFactors password:password keyFileDigest:keyFileDigest];
    }
    
    DatabaseModel* database = [[DatabaseModel alloc] initWithFormat:format compositeKeyFactors:ckf];

    [SampleItemsGenerator addSampleGroupAndRecordToRoot:database passwordConfig:AppPreferences.sharedInstance.passwordGenerationConfig];
    
    return database;
}

@end
