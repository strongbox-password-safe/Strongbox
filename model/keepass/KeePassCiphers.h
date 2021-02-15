//
//  KeePassCiphers.h
//  Strongbox
//
//  Created by Mark on 26/10/2018.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Cipher.h"

NS_ASSUME_NONNULL_BEGIN

@interface KeePassCiphers : NSObject

NSUUID* const aesCipherUuid(void);
NSData* aesCipherUuidData(void);

NSUUID* const aesKdbx3KdfCipherUuid(void);
NSData* aesKdbx3KdfCipherUuidData(void);
NSUUID* const aesKdbx4KdfCipherUuid(void);
NSData* aesKdbx4KdfCipherUuidData(void);

NSUUID* const argon2dCipherUuid(void);
NSData* argon2dCipherUuidData(void);

NSUUID* const argon2idCipherUuid(void);
NSData* argon2idCipherUuidData(void);

NSUUID* const chaCha20CipherUuid(void);
NSData* chaCha20CipherUuidData(void);

NSUUID* const twoFishCipherUuid(void);
NSData* twoFishCipherUuidData(void);


NSString* innerEncryptionString(uint32_t innerRandomStreamId);
NSString* keyDerivationAlgorithmString(NSUUID* uuid);
NSString* outerEncryptionAlgorithmString(NSUUID* uuid);

id<Cipher>__nullable getCipher(NSUUID* cipherUuid);

@end

NS_ASSUME_NONNULL_END
