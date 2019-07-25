//
//  OpenSafeSequenceHelper.h
//  Strongbox-iOS
//
//  Created by Mark on 12/10/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SafeMetaData.h"
#import "Model.h"

NS_ASSUME_NONNULL_BEGIN

typedef void(^CompletionBlock)(Model*_Nullable model, NSError*_Nullable error);

@interface OpenSafeSequenceHelper : NSObject

- (instancetype)init NS_UNAVAILABLE;

+ (void)beginSequenceWithViewController:(UIViewController*)viewController
                                   safe:(SafeMetaData*)safe
                    canConvenienceEnrol:(BOOL)canConvenienceEnrol
                         isAutoFillOpen:(BOOL)isAutoFillOpen
                 manualOpenOfflineCache:(BOOL)manualOpenOfflineCache
                             completion:(CompletionBlock)completion;

+ (void)beginSequenceWithViewController:(UIViewController*)viewController
                                   safe:(SafeMetaData*)safe
                    canConvenienceEnrol:(BOOL)canConvenienceEnrol
                         isAutoFillOpen:(BOOL)isAutoFillOpen
                 manualOpenOfflineCache:(BOOL)manualOpenOfflineCache
            biometricAuthenticationDone:(BOOL)biometricAuthenticationDone
                             completion:(CompletionBlock)completion;

+ (void)beginSequenceWithViewController:(UIViewController*)viewController
                                   safe:(SafeMetaData*)safe
                      openAutoFillCache:(BOOL)openAutoFillCache
                    canConvenienceEnrol:(BOOL)canConvenienceEnrol
                         isAutoFillOpen:(BOOL)isAutoFillOpen
                 manualOpenOfflineCache:(BOOL)manualOpenOfflineCache
            biometricAuthenticationDone:(BOOL)biometricAuthenticationDone
                             completion:(CompletionBlock)completion;

@end

NS_ASSUME_NONNULL_END
