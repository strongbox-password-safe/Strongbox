//
//  CompositeKey.h
//  Strongbox
//
//  Created by Mark on 16/07/2019.
//  Copyright © 2019 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

//typedef void (^YubiKeyCRResponseBlock)(NSData* response);
//typedef void (^YubiKeyCRHandlerBlock)(NSData* challenge, YubiKeyCRResponseBlock completion);

@interface CompositeKeyFactors : NSObject

+ (instancetype)password:(NSString*_Nullable)password;
+ (instancetype)password:(NSString*_Nullable)password keyFileDigest:(NSData*_Nullable)keyFileDigest;
+ (instancetype)password:(NSString*_Nullable)password keyFileDigest:(NSData*_Nullable)keyFileDigest yubiKeyResponse:(NSData* _Nullable)yubiKeyResponse;

- (instancetype)init NS_UNAVAILABLE;

- (instancetype)initWithPassword:(NSString*_Nullable)password;
- (instancetype)initWithPassword:(NSString*_Nullable)password keyFileDigest:(NSData*_Nullable)keyFileDigest;
- (instancetype)initWithPassword:(NSString*_Nullable)password keyFileDigest:(NSData*_Nullable)keyFileDigest yubiKeyResponse:(NSData* _Nullable)yubiKeyResponse NS_DESIGNATED_INITIALIZER;

@property (nullable, nonatomic) NSString* password;
@property (nullable, nonatomic) NSData* keyFileDigest;
@property (nullable, nonatomic) NSData* yubiKeyResponse; // Actually used to unlock / decrypt

@end

NS_ASSUME_NONNULL_END
