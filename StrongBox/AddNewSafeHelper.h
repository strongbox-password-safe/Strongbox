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

NS_ASSUME_NONNULL_BEGIN

@interface AddNewSafeHelper : NSObject

+ (void)createNewDatabase:(UIViewController*)vc
                     name:(NSString *)name
                 password:(NSString *)password
               keyFileUrl:(NSURL*)keyFileUrl
       onceOffKeyFileData:(NSData*)onceOffKeyFileData
            storageParams:(SelectedStorageParameters*)storageParams
                   format:(DatabaseFormat)format
               completion:(void (^)(SafeMetaData* metadata, NSError* error))completion;

+ (void)createNewExpressDatabase:(UIViewController*)vc
                            name:(NSString *)name
                        password:(NSString *)password
                      keyFileUrl:(NSURL*)keyFileUrl
              onceOffKeyFileData:(NSData*)onceOffKeyFileData
                          format:(DatabaseFormat)format
                      completion:(void (^)(SafeMetaData* metadata, NSError* error))completion;

NSData* getKeyFileDigest(NSURL* keyFileUrl, NSData* onceOffKeyFileData, BOOL checkForXml, NSError** error);

@end

NS_ASSUME_NONNULL_END
