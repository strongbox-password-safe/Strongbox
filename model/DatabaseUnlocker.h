//
//  DatabaseUnlocker.h
//  Strongbox
//
//  Created by Strongbox on 07/01/2021.
//  Copyright © 2021 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SafeMetaData.h"
#import "CompositeKeyFactors.h"
#import "Model.h"

typedef enum : NSUInteger {
    kUnlockDatabaseResultError,
    kUnlockDatabaseResultUserCancelled,
    kUnlockDatabaseResultSuccess,
    kUnlockDatabaseResultViewDebugSyncLogRequested,
    kUnlockDatabaseResultIncorrectCredentials,
} UnlockDatabaseResult;

typedef void(^UnlockDatabaseCompletionBlock)(UnlockDatabaseResult result, Model*_Nullable model, NSError*_Nullable innerStreamError, NSError*_Nullable error);

NS_ASSUME_NONNULL_BEGIN

@interface DatabaseUnlocker : NSObject

+ (instancetype)unlockerForDatabase:(SafeMetaData*)database
                     viewController:(UIViewController*)viewController
                     forceReadOnly:(BOOL)forcedReadOnly
                     isAutoFillOpen:(BOOL)isAutoFillOpen
                        offlineMode:(BOOL)offlineMode;

- (void)unlockLocalWithKey:(CompositeKeyFactors*)key
        keyFromConvenience:(BOOL)keyFromConvenience
                completion:(UnlockDatabaseCompletionBlock)completion;

- (void)unlockAtUrl:(NSURL*)url
                key:(CompositeKeyFactors*)key
 keyFromConvenience:(BOOL)keyFromConvenience
         completion:(UnlockDatabaseCompletionBlock)completion;

+ (Model*_Nullable)expressTryUnlockWithKey:(SafeMetaData*)database key:(CompositeKeyFactors*)key;

@end

NS_ASSUME_NONNULL_END
