//
//  YubiKeyManager.h
//  Strongbox
//
//  Created by Mark on 18/02/2020.
//  Copyright © 2020 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "HardwareKeyData.h"
#import "CompositeKeyFactors.h"
#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

typedef void (^GetAvailableKeyCompletion)(HardwareKeyData*_Nullable yubiKeyData);
typedef void (^ChallengeResponseCompletion)(NSData* response, NSError* error);
typedef NSWindow* _Nonnull (^MacHardwareKeyManagerOnDemandUIProviderBlock)(void); 

@interface MacHardwareKeyManager : NSObject

+ (instancetype)sharedInstance;

- (void)getAvailableKey:(GetAvailableKeyCompletion)completion;
- (void)challengeResponse:(NSData*)challenge slot:(NSInteger)slot completion:(ChallengeResponseCompletion)completion;

- (void)compositeKeyFactorCr:(NSData*)challenge
                  windowHint:(NSWindow*_Nullable)windowHint
                        slot:(NSInteger)slot
                  completion:(YubiKeyCRResponseBlock)completion;

- (void)compositeKeyFactorCr:(NSData*)challenge
                        slot:(NSInteger)slot
                  completion:(YubiKeyCRResponseBlock)completion
      onDemandWindowProvider:(MacHardwareKeyManagerOnDemandUIProviderBlock)onDemandWindowProvider;

@end

NS_ASSUME_NONNULL_END
