//
//  OpenSafeSequenceHelper.h
//  Strongbox-iOS
//
//  Created by Mark on 12/10/2018.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "DatabasePreferences.h"
#import "Model.h"
#import "DatabaseUnlocker.h"

NS_ASSUME_NONNULL_BEGIN

@interface UnlockDatabaseSequenceHelper : NSObject

- (instancetype)init NS_UNAVAILABLE;

+ (instancetype)helperWithViewController:(UIViewController*)viewController
                                database:(DatabasePreferences*)database;

+ (instancetype)helperWithViewController:(UIViewController*)viewController
                                database:(DatabasePreferences*)database
                          isAutoFillOpen:(BOOL)isAutoFillOpen
              offlineExplicitlyRequested:(BOOL)offlineExplicitlyRequested;

- (void)beginUnlockSequence:(UnlockDatabaseCompletionBlock)completion;

- (void)beginUnlockSequence:(BOOL)isAutoFillQuickTypeOpen
        biometricPreCleared:(BOOL)biometricPreCleared
        noConvenienceUnlock:(BOOL)noConvenienceUnlock
                 completion:(UnlockDatabaseCompletionBlock)completion;

@end

NS_ASSUME_NONNULL_END
