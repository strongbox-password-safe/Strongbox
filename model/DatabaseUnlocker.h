//
//  DatabaseUnlocker.h
//  Strongbox
//
//  Created by Strongbox on 07/01/2021.
//  Copyright © 2021 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "CompositeKeyFactors.h"
#import "Model.h"

typedef NS_ENUM(NSUInteger, UnlockDatabaseResult) {
    kUnlockDatabaseResultError,
    kUnlockDatabaseResultUserCancelled,
    kUnlockDatabaseResultSuccess,
    kUnlockDatabaseResultViewDebugSyncLogRequested,
    kUnlockDatabaseResultIncorrectCredentials,
};

typedef void(^UnlockDatabaseCompletionBlock)(UnlockDatabaseResult result, Model*_Nullable model, NSError*_Nullable innerStreamError, NSError*_Nullable error);

NS_ASSUME_NONNULL_BEGIN

@interface DatabaseUnlocker : NSObject

+ (instancetype)unlockerForDatabase:(METADATA_PTR)database
                     viewController:(VIEW_CONTROLLER_PTR)viewController
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

+ (Model*_Nullable)expressTryUnlockWithKey:(METADATA_PTR)database key:(CompositeKeyFactors*)key;

@property BOOL alertOnJustPwdWrong;

@end

NS_ASSUME_NONNULL_END
