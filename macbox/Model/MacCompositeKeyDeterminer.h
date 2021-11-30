//
//  MacCompositeKeyDeterminer.h
//  MacBox
//
//  Created by Strongbox on 01/11/2021.
//  Copyright © 2021 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "CompositeKeyDeterminer.h"

NS_ASSUME_NONNULL_BEGIN

@interface MacCompositeKeyDeterminer : NSObject

+ (instancetype)determinerWithViewController:(VIEW_CONTROLLER_PTR)viewController
                                    database:(METADATA_PTR)database
                              isAutoFillOpen:(BOOL)isAutoFillOpen;


+ (instancetype)determinerWithViewController:(VIEW_CONTROLLER_PTR)viewController
                                    database:(METADATA_PTR)database
                              isAutoFillOpen:(BOOL)isAutoFillOpen
                     isAutoFillQuickTypeOpen:(BOOL)isAutoFillQuickTypeOpen;

- (void)getCkfs:(CompositeKeyDeterminedBlock)completion;

- (void)getCkfsManually:(CompositeKeyDeterminedBlock)completion;

- (void)getCkfsWithBiometrics:(NSString*_Nullable)keyFileBookmark
         yubiKeyConfiguration:(YubiKeyConfiguration*_Nullable)yubiKeyConfiguration
                   completion:(CompositeKeyDeterminedBlock)completion;

- (void)getCkfsWithExplicitPassword:(NSString*_Nullable)password
                    keyFileBookmark:(NSString*_Nullable)keyFileBookmark
               yubiKeyConfiguration:(YubiKeyConfiguration*_Nullable)yubiKeyConfiguration
                         completion:(CompositeKeyDeterminedBlock)completion;

@property (readonly) BOOL bioOrWatchUnlockIsPossible;

+ (BOOL)bioOrWatchUnlockIsPossible:(DatabaseMetadata*)database;



+ (CompositeKeyFactors* _Nullable)getCkfsWithConfigs:(NSString*_Nullable)password
                           keyFileBookmark:(NSString*_Nullable)keyFileBookmark
                      yubiKeyConfiguration:(YubiKeyConfiguration*_Nullable)yubiKeyConfiguration
          hardwareKeyInteractionWindowHint:(NSWindow*)hardwareKeyInteractionWindowHint
                         formatKeyFileHint:(DatabaseFormat)formatKeyFileHint
                                     error:(NSError**)outError;
@end

NS_ASSUME_NONNULL_END
