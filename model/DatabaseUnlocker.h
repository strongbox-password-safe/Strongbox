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

NS_ASSUME_NONNULL_BEGIN

typedef void(^UnlockDatabaseCompletionBlock)(UnlockDatabaseResult result, Model*_Nullable model, NSError*_Nullable error);
typedef VIEW_CONTROLLER_PTR _Nonnull (^UnlockDatabaseOnDemandUIProviderBlock)(void); 

@interface DatabaseUnlocker : NSObject

+ (instancetype)unlockerForDatabase:(METADATA_PTR)database
                     viewController:(VIEW_CONTROLLER_PTR)viewController
                      forceReadOnly:(BOOL)forcedReadOnly
   isNativeAutoFillAppExtensionOpen:(BOOL)isNativeAutoFillAppExtensionOpen
                        offlineMode:(BOOL)offlineMode;

+ (instancetype)unlockerForDatabase:(METADATA_PTR)database
                      forceReadOnly:(BOOL)forcedReadOnly
   isNativeAutoFillAppExtensionOpen:(BOOL)isNativeAutoFillAppExtensionOpen
                        offlineMode:(BOOL)offlineMode
                 onDemandUiProvider:(UnlockDatabaseOnDemandUIProviderBlock)onDemandUiProvider;

- (void)unlockLocalWithKey:(CompositeKeyFactors*)key
        keyFromConvenience:(BOOL)keyFromConvenience
                completion:(UnlockDatabaseCompletionBlock)completion;

- (void)unlockAtUrl:(NSURL*)url
                key:(CompositeKeyFactors*)key
 keyFromConvenience:(BOOL)keyFromConvenience
         completion:(UnlockDatabaseCompletionBlock)completion;

+ (Model*_Nullable)expressTryUnlockWithKey:(METADATA_PTR)database key:(CompositeKeyFactors*)key;

@property BOOL alertOnJustPwdWrong;
@property BOOL noProgressSpinner;

@end

NS_ASSUME_NONNULL_END
