//
//  YubiKeyManager.h
//  Strongbox
//
//  Created by Mark on 18/02/2020.
//  Copyright © 2020 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "YubiKeyData.h"
#import "CompositeKeyFactors.h"
#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

typedef void (^GetAvailableYubikeyCompletion)(YubiKeyData* yubiKeyData);
typedef void (^ChallengeResponseCompletion)(NSData* response, NSError* error);

@interface MacYubiKeyManager : NSObject

+ (instancetype)sharedInstance;

- (void)getAvailableYubikey:(GetAvailableYubikeyCompletion)completion;
- (void)challengeResponse:(NSData*)challenge slot:(NSInteger)slot completion:(ChallengeResponseCompletion)completion;

- (void)compositeKeyFactorCr:(NSData*)challenge
                  windowHint:(NSWindow*_Nullable)windowHint
                        slot:(NSInteger)slot
              slotIsBlocking:(BOOL)slotIsBlocking
                  completion:(YubiKeyCRResponseBlock)completion;

@end

NS_ASSUME_NONNULL_END
