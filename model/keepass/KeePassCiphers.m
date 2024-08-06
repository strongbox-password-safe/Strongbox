//
//  KeePassCiphers.m
//  Strongbox
//
//  Created by Mark on 26/10/2018.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import "KeePassCiphers.h"
#import "AesCipher.h"
#import "ChaCha20Cipher.h"
#import "TwoFishCipher.h"
#import "KeePassConstants.h"
#import "SBLog.h"

@implementation KeePassCiphers

static NSString* const aesKdbx3Kdf = @"C9D9F39A-628A-4460-BF74-0D08C18A4FEA";
static NSString* const aesKdbx4Kdf = @"7C02BB82-79A7-4AC0-927D-114A00648238";
static NSString* const aesUuid = @"31C1F2E6-BF71-4350-BE58-05216AFC5AFF";
static NSString* const chaCha20Uuid = @"D6038A2B-8B6F-4CB5-A524-339A31DBB59A";
static NSString* const argon2dUuid = @"EF636DDF-8C29-444B-91F7-A9A403E30A0C";
static NSString* const argon2idUuid = @"9E298B19-56DB-4773-B23D-FC3EC6F0A1E6";
static NSString* const twoFishUuid = @"AD68F29F-576F-4BB9-A36A-D47AF965346C";

NSUUID* const aesKdbx3KdfCipherUuid(void) {
    static NSUUID* foo = nil;
    
    if (!foo) {
        foo = [[NSUUID alloc] initWithUUIDString:aesKdbx3Kdf];
    }
    
    return foo;
}

NSData* aesKdbx3KdfCipherUuidData(void) {
    static NSData* foo = nil;
    
    if(!foo) {
        uuid_t uuid;
        [aesKdbx3KdfCipherUuid() getUUIDBytes:uuid];
        foo = [NSData dataWithBytes:uuid length:sizeof(uuid_t)];
    }
    
    return foo;
}

NSUUID* const aesKdbx4KdfCipherUuid(void) {
    static NSUUID* foo = nil;
    
    if (!foo) {
        foo = [[NSUUID alloc] initWithUUIDString:aesKdbx4Kdf];
    }
    
    return foo;
}

NSData* aesKdbx4KdfCipherUuidData(void) {
    static NSData* foo = nil;
    
    if(!foo) {
        uuid_t uuid;
        [aesKdbx4KdfCipherUuid() getUUIDBytes:uuid];
        foo = [NSData dataWithBytes:uuid length:sizeof(uuid_t)];
    }
    
    return foo;
}

NSUUID* const twoFishCipherUuid(void) {
    static NSUUID* foo = nil;
    
    if (!foo) {
        foo = [[NSUUID alloc] initWithUUIDString:twoFishUuid];
    }
    
    return foo;
}

NSData* twoFishCipherUuidData(void) {
    static NSData* foo = nil;
    
    if(!foo) {
        uuid_t uuid;
        [twoFishCipherUuid() getUUIDBytes:uuid];
        foo = [NSData dataWithBytes:uuid length:sizeof(uuid_t)];
    }
    
    return foo;
}

NSUUID* const chaCha20CipherUuid(void) {
    static NSUUID* foo = nil;
    
    if (!foo) {
        foo = [[NSUUID alloc] initWithUUIDString:chaCha20Uuid];
    }
    
    return foo;
}

NSData* chaCha20CipherUuidData(void) {
    static NSData* foo = nil;
    
    if(!foo) {
        uuid_t uuid;
        [chaCha20CipherUuid() getUUIDBytes:uuid];
        foo = [NSData dataWithBytes:uuid length:sizeof(uuid_t)];
    }
    
    return foo;
}

NSUUID* const argon2dCipherUuid(void) {
    static NSUUID* foo = nil;
    
    if (!foo) {
        foo = [[NSUUID alloc] initWithUUIDString:argon2dUuid];
    }
    
    return foo;
}

NSData* argon2dCipherUuidData(void) {
    static NSData* foo = nil;
    
    if(!foo) {
        uuid_t uuid;
        [argon2dCipherUuid() getUUIDBytes:uuid];
        foo = [NSData dataWithBytes:uuid length:sizeof(uuid_t)];
    }
    
    return foo;
}

NSUUID* const argon2idCipherUuid(void) {
    static NSUUID* foo = nil;
    
    if (!foo) {
        foo = [[NSUUID alloc] initWithUUIDString:argon2idUuid];
    }
    
    return foo;
}

NSData* argon2idCipherUuidData(void) {
    static NSData* foo = nil;
    
    if(!foo) {
        uuid_t uuid;
        [argon2idCipherUuid() getUUIDBytes:uuid];
        foo = [NSData dataWithBytes:uuid length:sizeof(uuid_t)];
    }
    
    return foo;
}

NSUUID* const aesCipherUuid(void) {
    static NSUUID* foo = nil;
    
    if (!foo) {
        foo = [[NSUUID alloc] initWithUUIDString:aesUuid];
    }
    
    return foo;
}

NSData* aesCipherUuidData(void) {
    static NSData* foo = nil;
    
    if(!foo) {
        uuid_t uuid;
        [aesCipherUuid() getUUIDBytes:uuid];
        foo = [NSData dataWithBytes:uuid length:sizeof(uuid_t)];
    }
    
    return foo;
}

NSString* innerEncryptionString(uint32_t innerRandomStreamId) {
    switch (innerRandomStreamId) {
        case kInnerStreamPlainText:
            return @"None (Plaintext)";
            break;
        case kInnerStreamArc4:
            return @"ARC4";
            break;
        case kInnerStreamSalsa20:
            return @"Salsa20";
            break;
        case kInnerStreamChaCha20:
            return @"ChaCha20";
            break;
        default:
            return [NSString stringWithFormat:@"Unknown (%d)", innerRandomStreamId];
            break;
    }
}

NSString* keyDerivationAlgorithmString(NSUUID* uuid){
    if([uuid isEqual:aesCipherUuid()]) {
        return @"AES";
    }
    else if([uuid isEqual:aesKdbx3KdfCipherUuid()]) {
        return @"AES (KDBX 3)";
    }
    else if([uuid isEqual:aesKdbx4KdfCipherUuid()]) {
        return @"AES (KDBX 4)";
    }
    else if([uuid isEqual:argon2dCipherUuid()]) {
        return @"Argon2d";
    }
    else if([uuid isEqual:argon2idCipherUuid()]) {
        return @"Argon2id";
    }

    return @"<Unknown>";
}

NSString* outerEncryptionAlgorithmString(NSUUID* uuid) {
    if([uuid isEqual:aesCipherUuid()]) {
        return @"AES-256";
    }
    else if([uuid isEqual:chaCha20CipherUuid()]) {
        return @"ChaCha20";
    }
    else if([uuid isEqual:twoFishCipherUuid()]) {
        return @"TwoFish";
    }
    
    return @"<Unknown>";
}

id<Cipher> getCipher(NSUUID* cipherUuid) {
    if([cipherUuid isEqual:aesCipherUuid()]) {
        return [[AesCipher alloc] init];
    }
    else if([cipherUuid isEqual:chaCha20CipherUuid()]) {
        return [[ChaCha20Cipher alloc] init];
    }
    else if([cipherUuid isEqual:twoFishCipherUuid()]) {
        return [[TwoFishCipher alloc] init];
    }
    else {
        slog(@"Unknown Cipher ID, cannot create. [%@]", cipherUuid.UUIDString);
    }
    
    return nil;
}

@end
