//
//  CompositeKeyDeterminer.h
//  Strongbox
//
//  Created by Strongbox on 06/01/2021.
//  Copyright © 2021 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#import "CompositeKeyFactors.h"
#import "SafeMetaData.h"

NS_ASSUME_NONNULL_BEGIN

typedef enum : NSUInteger {
    kGetCompositeKeyResultError,
    kGetCompositeKeyResultUserCancelled,
    kGetCompositeKeyResultDuressIndicated,
    kGetCompositeKeyResultSuccess,
} GetCompositeKeyResult;

typedef void(^CompositeKeyDeterminedBlock)(GetCompositeKeyResult result, CompositeKeyFactors*_Nullable factors, BOOL fromConvenience, NSError*_Nullable error);

@interface CompositeKeyDeterminer : NSObject

+ (instancetype)determinerWithViewController:(UIViewController *)viewController
                                        database:(SafeMetaData *)safe
                              isAutoFillOpen:(BOOL)isAutoFillOpen
                     isAutoFillQuickTypeOpen:(BOOL)isAutoFillQuickTypeOpen
                         biometricPreCleared:(BOOL)biometricPreCleared
                         noConvenienceUnlock:(BOOL)noConvenienceUnlock;

- (instancetype)init NS_UNAVAILABLE;

- (instancetype)initWithViewController:(UIViewController *)viewController
                                  database:(SafeMetaData *)safe
                        isAutoFillOpen:(BOOL)isAutoFillOpen
               isAutoFillQuickTypeOpen:(BOOL)isAutoFillQuickTypeOpen
                   biometricPreCleared:(BOOL)biometricPreCleared
                   noConvenienceUnlock:(BOOL)noConvenienceUnlock;


- (void)getCredentials:(CompositeKeyDeterminedBlock)completion;

@property (readonly) BOOL isAutoFillConvenienceAutoLockPossible;

@end

NS_ASSUME_NONNULL_END
