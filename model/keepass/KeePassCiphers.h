//
//  KeePassCiphers.h
//  Strongbox
//
//  Created by Mark on 26/10/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Cipher.h"

NS_ASSUME_NONNULL_BEGIN

@interface KeePassCiphers : NSObject

NSUUID* const aesCipherUuid(void);
NSData* aesCipherUuidData(void);

NSUUID* const argon2CipherUuid(void);
NSData* argon2CipherUuidData(void);

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
