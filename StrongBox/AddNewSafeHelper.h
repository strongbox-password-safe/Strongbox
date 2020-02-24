//
//  AddNewSafeHelper.h
//  Strongbox
//
//  Created by Mark on 05/12/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SafeStorageProvider.h"
#import "DatabaseModel.h"
#import "SelectedStorageParameters.h"

extern const DatabaseFormat kDefaultFormat;

NS_ASSUME_NONNULL_BEGIN

@interface AddNewSafeHelper : NSObject

+ (void)createNewDatabase:(UIViewController*)vc
                     name:(NSString *)name
                 password:(NSString *)password
               keyFileUrl:(NSURL*)keyFileUrl
       onceOffKeyFileData:(NSData*)onceOffKeyFileData
            yubiKeyConfig:(YubiKeyHardwareConfiguration*_Nullable)yubiKeyConfig
            storageParams:(SelectedStorageParameters*)storageParams
                   format:(DatabaseFormat)format
               completion:(void (^)(BOOL userCancelled, SafeMetaData*_Nullable metadata, NSError*_Nullable error))completion;

+ (void)createNewExpressDatabase:(UIViewController*)vc
                            name:(NSString *)name
                        password:(NSString *)password
                      completion:(void (^)(BOOL userCancelled, SafeMetaData* metadata, NSError* error))completion;

NSData* getKeyFileDigest(NSURL* keyFileUrl, NSData* onceOffKeyFileData, DatabaseFormat format, NSError** error);
NSData* getKeyFileData(NSURL* keyFileUrl, NSData* onceOffKeyFileData, NSError** error);

@end

NS_ASSUME_NONNULL_END
