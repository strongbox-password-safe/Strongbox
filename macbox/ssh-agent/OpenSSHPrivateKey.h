//
//  OpenSSHPrivateKey.h
//  MacBox
//
//  Created by Strongbox on 26/05/2023.
//  Copyright © 2023 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SBLog.h"

NS_ASSUME_NONNULL_BEGIN

@interface OpenSSHPrivateKey : NSObject

+ (instancetype _Nullable)fromData:(NSData*)data;
+ (instancetype _Nullable)newRsa;
+ (instancetype _Nullable)newEd25519;

- (BOOL)isEqualTo:(id _Nullable)object;

@property (readonly) NSString* fingerprint;
@property (readonly) NSString* publicKey;
@property (readonly) NSString* privateKey;
@property (readonly) NSString* type;

@property (readonly) NSData* data;


@property (readonly) NSString* publicKeySerializationBlobBase64;  
@property (readonly) NSData* publicKeySerializationBlob; 

@property (readonly) BOOL isPassphraseProtected;

- (BOOL)validatePassphrase:(NSString*)passphrase;
- (NSData*_Nullable)sign:(NSData*)challenge passphrase:(NSString*)passphrase flags:(u_int)flags;

- (NSData*_Nullable)exportFileBlob:(NSString*)originalPassphrase exportPassphrase:(NSString*)exportPassphrase;

@end

NS_ASSUME_NONNULL_END
