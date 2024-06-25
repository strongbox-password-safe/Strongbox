//
//  AddNewSafeHelper.h
//  Strongbox
//
//  Created by Mark on 05/12/2018.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
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
          keyFileBookmark:(NSString * _Nullable)keyFileBookmark
          keyFileFileName:(NSString * _Nullable)keyFileFileName
       onceOffKeyFileData:(NSData* _Nullable)onceOffKeyFileData
            yubiKeyConfig:(YubiKeyHardwareConfiguration*_Nullable)yubiKeyConfig
            storageParams:(SelectedStorageParameters*)storageParams
                   format:(DatabaseFormat)format
               completion:(void (^)(BOOL userCancelled, DatabasePreferences*_Nullable metadata, NSData*_Nullable initialSnapshot, NSError*_Nullable error))completion;

+ (void)createNewExpressDatabase:(UIViewController*)vc
                            name:(NSString *)name
                        password:(NSString *)password
                      completion:(void (^)(BOOL userCancelled, DatabasePreferences*_Nullable metadata, NSData*_Nullable initialSnapshot, NSError*_Nullable error))completion;

+ (void)createNewExpressDatabase:(UIViewController*)vc
                            name:(NSString *)name
                           model:(DatabaseModel*)model
                      completion:(void (^)(BOOL userCancelled, DatabasePreferences*_Nullable metadata, NSData*_Nullable initialSnapshot, NSError*_Nullable error))completion;

+ (void)createNewExpressDatabase:(UIViewController*)vc
                            name:(NSString *)name
                        password:(NSString *)password
                      forceLocal:(BOOL)forceLocal
                      completion:(void (^)(BOOL userCancelled, DatabasePreferences*_Nullable metadata, NSData*_Nullable initialSnapshot, NSError*_Nullable error))completion;

@end

NS_ASSUME_NONNULL_END
