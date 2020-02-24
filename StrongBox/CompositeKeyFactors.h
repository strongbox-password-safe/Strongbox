//
//  CompositeKey.h
//  Strongbox
//
//  Created by Mark on 16/07/2019.
//  Copyright © 2019 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef void (^YubiKeyCRResponseBlock)(BOOL userCancelled, NSData*_Nullable response, NSError*_Nullable error);
typedef void (^YubiKeyCRHandlerBlock)(NSData* challenge, YubiKeyCRResponseBlock completion);

@interface CompositeKeyFactors : NSObject

+ (instancetype)password:(NSString*_Nullable)password;
+ (instancetype)password:(NSString*_Nullable)password keyFileDigest:(NSData*_Nullable)keyFileDigest;
+ (instancetype)password:(NSString*_Nullable)password keyFileDigest:(NSData*_Nullable)keyFileDigest yubiKeyCR:(YubiKeyCRHandlerBlock _Nullable)yubiKeyCR;

- (instancetype)init NS_UNAVAILABLE;

- (instancetype)initWithPassword:(NSString*_Nullable)password;
- (instancetype)initWithPassword:(NSString*_Nullable)password keyFileDigest:(NSData*_Nullable)keyFileDigest;
- (instancetype)initWithPassword:(NSString*_Nullable)password keyFileDigest:(NSData*_Nullable)keyFileDigest yubiKeyCR:(YubiKeyCRHandlerBlock _Nullable)yubiKeyCR NS_DESIGNATED_INITIALIZER;

- (instancetype)clone;

@property (nullable, nonatomic) NSString* password;
@property (nullable, nonatomic) NSData* keyFileDigest;
@property (nullable, copy) YubiKeyCRHandlerBlock yubiKeyCR;

@end

NS_ASSUME_NONNULL_END
