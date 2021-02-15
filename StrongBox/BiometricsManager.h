//
//  BiometricsManager.h
//  Strongbox
//
//  Created by Mark on 24/10/2019.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface BiometricsManager : NSObject

+ (instancetype)sharedInstance;

+ (BOOL)isBiometricIdAvailable;

- (BOOL)requestBiometricId:(NSString*)reason
                completion:(void(^)(BOOL success, NSError * __nullable error))completion;

- (BOOL)requestBiometricId:(NSString *)reason
             fallbackTitle:(NSString*_Nullable)fallbackTitle
                completion:(void(^_Nullable)(BOOL success, NSError * __nullable error))completion;

@property (readonly) NSString* biometricIdName;
- (NSString*)getBiometricIdName;

- (BOOL)isBiometricDatabaseStateRecorded:(BOOL)autoFill;
- (void)recordBiometricDatabaseState:(BOOL)autoFill;
- (BOOL)isBiometricDatabaseStateHasChanged:(BOOL)autoFill;
- (void)clearBiometricRecordedDatabaseState;

- (BOOL)isFaceId;

@end

NS_ASSUME_NONNULL_END
