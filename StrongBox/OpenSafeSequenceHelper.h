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

typedef enum : NSUInteger {
    kUnlockDatabaseResultError,
    kUnlockDatabaseResultUserCancelled,
    kUnlockDatabaseResultSuccess,
    kUnlockDatabaseResultViewDebugSyncLogRequested,
} UnlockDatabaseResult;

typedef void(^UnlockDatabaseCompletionBlock)(UnlockDatabaseResult result, Model*_Nullable model, const NSError*_Nullable error);

@interface OpenSafeSequenceHelper : NSObject

- (instancetype)init NS_UNAVAILABLE;

+ (void)beginSequenceWithViewController:(UIViewController*)viewController
                                   safe:(SafeMetaData*)safe
                    canConvenienceEnrol:(BOOL)canConvenienceEnrol
                         isAutoFillOpen:(BOOL)isAutoFillOpen
                          openLocalOnly:(BOOL)openLocalOnly
                             completion:(UnlockDatabaseCompletionBlock)completion;

+ (void)beginSequenceWithViewController:(UIViewController*)viewController
                                   safe:(SafeMetaData*)safe
                    canConvenienceEnrol:(BOOL)canConvenienceEnrol
                         isAutoFillOpen:(BOOL)isAutoFillOpen
                          openLocalOnly:(BOOL)openLocalOnly
            biometricAuthenticationDone:(BOOL)biometricAuthenticationDone
                             completion:(UnlockDatabaseCompletionBlock)completion;

+ (void)beginSequenceWithViewController:(UIViewController*)viewController
                                   safe:(SafeMetaData*)safe
                    canConvenienceEnrol:(BOOL)canConvenienceEnrol
                         isAutoFillOpen:(BOOL)isAutoFillOpen
                          openLocalOnly:(BOOL)openLocalOnly
            biometricAuthenticationDone:(BOOL)biometricAuthenticationDone
                    noConvenienceUnlock:(BOOL)noConvenienceUnlock
                             completion:(UnlockDatabaseCompletionBlock)completion;

+ (void)beginSequenceWithViewController:(UIViewController*)viewController
                                   safe:(SafeMetaData*)safe
                    canConvenienceEnrol:(BOOL)canConvenienceEnrol
                         isAutoFillOpen:(BOOL)isAutoFillOpen
                isAutoFillQuickTypeOpen:(BOOL)isAutoFillQuickTypeOpen
                          openLocalOnly:(BOOL)openLocalOnly
            biometricAuthenticationDone:(BOOL)biometricAuthenticationDone
                    noConvenienceUnlock:(BOOL)noConvenienceUnlock
                             completion:(UnlockDatabaseCompletionBlock)completion;

NSData*_Nullable getKeyFileDigest(NSString* keyFileBookmark, NSData* onceOffKeyFileData, DatabaseFormat format, NSError** error);
NSData*_Nullable getKeyFileData(NSString* keyFileBookmark, NSData* onceOffKeyFileData, NSError** error);

@end

NS_ASSUME_NONNULL_END
