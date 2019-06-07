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

const DatabaseFormat kDefaultFormat = kKeePass4;

@implementation AddNewSafeHelper

+ (void)createNewExpressDatabase:(UIViewController*)vc
                            name:(NSString *)name
                        password:(NSString *)password
                      completion:(void (^)(SafeMetaData* metadata, NSError* error))completion {
    NSError* error;
    DatabaseModel *database = getNewDatabase(password, nil, nil, kDefaultFormat, &error);
    
    if(!database) {
        completion(nil, error);
        return;
    }
    
    BOOL iCloud = Settings.sharedInstance.iCloudOn;
    
    [AddNewSafeHelper createDatabase:vc
                                name:name
                          keyFileUrl:nil
                            database:database
                            provider:iCloud ? AppleICloudProvider.sharedInstance : LocalDeviceStorageProvider.sharedInstance
                        parentFolder:nil
                          completion:completion];
}

+ (void)createNewDatabase:(UIViewController *)vc
                     name:(NSString *)name
                 password:(NSString *)password
               keyFileUrl:(NSURL *)keyFileUrl
       onceOffKeyFileData:(NSData *)onceOffKeyFileData
            storageParams:(SelectedStorageParameters *)storageParams
                   format:(DatabaseFormat)format
               completion:(void (^)(SafeMetaData*, NSError*))completion {
    NSError* error;
    DatabaseModel *database = getNewDatabase(password, keyFileUrl, onceOffKeyFileData, format, &error);
    
    if(!database) {
        completion(nil, error);
        return;
    }
    
    [AddNewSafeHelper createDatabase:vc
                                name:name
                          keyFileUrl:keyFileUrl
                            database:database
                            provider:storageParams.provider
                        parentFolder:storageParams.parentFolder
                          completion:completion];
}

+ (void)createDatabase:(UIViewController*)vc
                  name:(NSString*)name
            keyFileUrl:(NSURL *)keyFileUrl
              database:(DatabaseModel*)database
              provider:(id<SafeStorageProvider>)provider
          parentFolder:(NSObject*)parentFolder
           completion:(void (^)(SafeMetaData* metadata, NSError* error))completion {
    NSError *error;
    NSData *data = [database getAsData:&error];
    
    if (data == nil) {
        completion(nil, error);
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
             
             dispatch_async(dispatch_get_main_queue(), ^(void) {
                 completion(metadata, error);
             });
         }];
    });
}

static DatabaseModel* getNewDatabase(NSString* password, NSURL* keyFileUrl, NSData* onceOffKeyFileData, DatabaseFormat format, NSError** error) {
    NSData* keyFileDigest = getKeyFileDigest(keyFileUrl, onceOffKeyFileData, format, error);
    
    if(*error) {
        return nil;
    }
    
    return [[DatabaseModel alloc] initNewWithPassword:password keyFileDigest:keyFileDigest format:format];
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
