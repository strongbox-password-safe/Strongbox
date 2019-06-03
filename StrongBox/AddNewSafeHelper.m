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

@implementation AddNewSafeHelper

+ (void)createNewExpressDatabase:(UIViewController*)vc
                            name:(NSString *)name
                        password:(NSString *)password
                      keyFileUrl:(NSURL*)keyFileUrl
              onceOffKeyFileData:(NSData*)onceOffKeyFileData
                          format:(DatabaseFormat)format
                      completion:(void (^)(SafeMetaData* metadata, NSError* error))completion {
    NSError* error;
    DatabaseModel *database = getNewDatabase(password, keyFileUrl, onceOffKeyFileData, format, &error);
    
    if(!database) {
        completion(nil, error);
        return;
    }
    
    [AddNewSafeHelper createDatabase:vc
                                name:name
                          keyFileUrl:nil
                            database:database
                            provider:AppleICloudProvider.sharedInstance // TODO: Or Local?
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
             dispatch_async(dispatch_get_main_queue(), ^(void) {
                 completion(metadata, error);
             });
         }];
    });
}

static DatabaseModel* getNewDatabase(NSString* password, NSURL* keyFileUrl, NSData* onceOffKeyFileData, DatabaseFormat format, NSError** error) {
    NSData* keyFileDigest = getKeyFileDigest2(keyFileUrl, onceOffKeyFileData, format, error);
    
    if(*error) {
        return nil;
    }
    
    return [[DatabaseModel alloc] initNewWithPassword:password keyFileDigest:keyFileDigest format:format];
}

NSData* getKeyFileDigest2(NSURL* keyFileUrl, NSData* onceOffKeyFileData, DatabaseFormat format, NSError** error) {
    return getKeyFileDigest(keyFileUrl, onceOffKeyFileData, format != kKeePass1, error);
}

NSData* getKeyFileDigest(NSURL* keyFileUrl, NSData* onceOffKeyFileData, BOOL checkForXml, NSError** error) {
    NSData* keyFileData = nil;
    if (keyFileUrl) {
        keyFileData = [NSData dataWithContentsOfURL:keyFileUrl options:kNilOptions error:error];
    }
    else if (onceOffKeyFileData) {
        keyFileData = onceOffKeyFileData;
    }
    
    NSData *keyFileDigest = keyFileData ? [KeyFileParser getKeyFileDigestFromFileData:keyFileData checkForXml:checkForXml] : nil;

    return keyFileDigest;
}

@end
