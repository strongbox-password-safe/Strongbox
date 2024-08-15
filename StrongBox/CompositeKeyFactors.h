//
//  CompositeKey.h
//  Strongbox
//
//  Created by Mark on 16/07/2019.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "MMcGPair.h"

NS_ASSUME_NONNULL_BEGIN

typedef void (^YubiKeyCRResponseBlock)(BOOL userCancelled, NSData*_Nullable response, NSError*_Nullable error);
typedef void (^YubiKeyCRHandlerBlock)(NSData* challenge, YubiKeyCRResponseBlock completion);

@interface CompositeKeyFactors : NSObject

+ (instancetype)unitTestDefaults;

+ (instancetype)password:(NSString*_Nullable)password;
+ (instancetype)password:(NSString*_Nullable)password keyFileDigest:(NSData*_Nullable)keyFileDigest;
+ (instancetype)password:(NSString*_Nullable)password keyFileDigest:(NSData*_Nullable)keyFileDigest yubiKeyCR:(YubiKeyCRHandlerBlock _Nullable)yubiKeyCR;

- (instancetype)init NS_UNAVAILABLE;

- (instancetype)initWithPassword:(NSString*_Nullable)password;
- (instancetype)initWithPassword:(NSString*_Nullable)password keyFileDigest:(NSData*_Nullable)keyFileDigest;
- (instancetype)initWithPassword:(NSString*_Nullable)password keyFileDigest:(NSData*_Nullable)keyFileDigest yubiKeyCR:(YubiKeyCRHandlerBlock _Nullable)yubiKeyCR NS_DESIGNATED_INITIALIZER;

- (instancetype)clone;

@property (readonly, nullable, nonatomic) NSString* password;
@property (readonly, nullable, nonatomic) NSData* keyFileDigest;
@property (readonly, nullable, copy) YubiKeyCRHandlerBlock yubiKeyCR;

@property (readonly, nullable) MMcGPair<NSData*, NSData*>* lastChallengeResponse;

@property (readonly) BOOL isAmbiguousEmptyOrNullPassword;

@end

NS_ASSUME_NONNULL_END
