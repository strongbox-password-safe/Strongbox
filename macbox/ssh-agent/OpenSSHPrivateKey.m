//
//  OpenSSHPrivateKey.m
//  MacBox
//
//  Created by Strongbox on 26/05/2023.
//  Copyright © 2023 Mark McGuill. All rights reserved.
//

#import "OpenSSHPrivateKey.h"

#import <openssh-portable/sshkey.h>
#import <openssh-portable/sshbuf.h>
#import <openssh-portable/ssherr.h>
#import <openssh-portable/digest.h>
#import <openssh-portable/authfd.h>

#import "NSData+Extensions.h"
#import "NSString+Extensions.h"

static const u_int kDefaultRSABits = 3072;
static const u_int kDefaultEd25519Bits = 256;

@interface OpenSSHPrivateKey ()

@property NSData* fileBlobData;

@end

@implementation OpenSSHPrivateKey

+ (instancetype)fromData:(NSData*)data {
    return [[OpenSSHPrivateKey alloc] initWithData:data];
}

+ (instancetype)newRsa {
    return [OpenSSHPrivateKey newWithType:KEY_RSA bits:kDefaultRSABits];
}

+ (instancetype)newEd25519 {
    return [OpenSSHPrivateKey newWithType:KEY_ED25519 bits:kDefaultEd25519Bits];
}

- (instancetype)initWithData:(NSData*)data {
    self = [super init];

    if (self) {
        _fileBlobData = data;
        
        struct sshbuf *blob = sshbuf_from(data.bytes, data.length);
        if ( blob == nil ) {
            slog(@"🔴 Could not alloc blob from Key...");
            return nil;
        }

        
        
        int ret = sshkey_parse_private_fileblob(blob, "", NULL, NULL);
        
        _isPassphraseProtected = NO;
        if ( ret != SSH_ERR_SUCCESS ) {
            if ( ret == SSH_ERR_KEY_WRONG_PASSPHRASE ) {
                _isPassphraseProtected = YES;
            }
            else {
                slog(@"🔴 Could not parse key from blob... %s", ssh_err(ret));
                sshbuf_free(blob);
                return nil;
            }
        }

        
        
        struct sshkey *public = nil;
        ret = sshkey_parse_pubkey_from_private_fileblob_type(blob, KEY_UNSPEC, &public);
        sshbuf_free(blob);
        
        if ( ret != SSH_ERR_SUCCESS ) {
            slog(@"🔴 Could not get public key from private Key... %s", ssh_err(ret));
            return nil;
        }

        
        
        char* fp = sshkey_fingerprint(public, SSH_DIGEST_SHA256, SSH_FP_BASE64);
        if ( fp == nil ) {
            slog(@"🔴 Could not get public key from private Key... %s", ssh_err(ret));
            sshkey_free(public);
            return nil;
        }
        
        _fingerprint = [NSString stringWithCString:fp encoding:NSUTF8StringEncoding];
        free(fp);
        
        
        
        struct sshbuf *b = sshbuf_new();
        if (b == nil) {
            slog(@"🔴 Could not allocate buffer for public key text");
            sshkey_free(public);
            return nil;
        }
        
        int r = sshkey_format_text(public, b);
        if ( r != SSH_ERR_SUCCESS ) {
            slog(@"🔴 Could not sshkey_format_text... %s", ssh_err(ret));
            sshkey_free(public);
            return nil;
        }
        
        char* str = sshbuf_dup_string(b);
        _publicKey = [NSString stringWithCString:str encoding:NSUTF8StringEncoding];
        free(str);
        sshbuf_free(b);
        
        NSString* algo = [NSString stringWithFormat:@"%s", sshkey_type(public)];
        NSString* bits = [NSString stringWithFormat:@"%d", sshkey_size(public)];
        
        _type = [NSString stringWithFormat:NSLocalizedString(@"ssh_agent_algo_bits_fmt", @"%@ (%@ bits)"), algo, bits];
        
        
        
        u_char* bloop;
        size_t bloopLen;
        r = sshkey_plain_to_blob(public, &bloop, &bloopLen);
        if ( r != SSH_ERR_SUCCESS ) {
            slog(@"🔴 Could not sshkey_plain_to_blob... %s", ssh_err(ret));
            sshkey_free(public);
            return nil;
        }

        NSData* publicKeyBlob = [NSData dataWithBytes:bloop length:bloopLen];
        free(bloop);
        
        _publicKeySerializationBlobBase64 = publicKeyBlob.base64String;
        
        sshkey_free(public);
    }
    
    return self;
}

+ (instancetype)newWithType:(int)type bits:(u_int)bits {
    struct sshkey* key;
    int ret = sshkey_generate(type, bits, &key);
    if ( ret != SSH_ERR_SUCCESS ) {
        slog(@"🔴 %s", ssh_err(ret));
        return nil;
    }
    
    struct sshbuf *keyblob = NULL;
    if ((keyblob = sshbuf_new()) == NULL) {
        slog(@"🔴 Could not allocate");
        sshkey_free(key);
        return nil;
    }
    
    ret = sshkey_private_to_fileblob(key, keyblob, "", "", SSHKEY_PRIVATE_OPENSSH, NULL, 0);
    if ( ret != SSH_ERR_SUCCESS ) {
        slog(@"🔴 %s", ssh_err(ret));
        sshkey_free(key);
        sshbuf_free(keyblob);
        return nil;
    }
    
    NSMutableData* data = [NSMutableData dataWithLength:sshbuf_len(keyblob)];
    ret = sshbuf_get(keyblob, data.mutableBytes, data.length);
    if ( ret != SSH_ERR_SUCCESS ) {
        slog(@"🔴 %s", ssh_err(ret));
        sshbuf_free(keyblob);
        sshkey_free(key);
        return nil;
    }
    
    sshbuf_free(keyblob);
    sshkey_free(key);
    
    return [[OpenSSHPrivateKey alloc] initWithData:data];
}

- (NSData*)exportFileBlob:(NSString*)originalPassphrase exportPassphrase:(NSString*)exportPassphrase {
    const char* cOriginalPassphrase = [originalPassphrase cStringUsingEncoding:NSUTF8StringEncoding];
    const char* cExportPassphrase = [exportPassphrase cStringUsingEncoding:NSUTF8StringEncoding];

    if ( cOriginalPassphrase == nil || cExportPassphrase == nil ) {
        slog(@"🔴 sign: Could not get s String passphrase");
        return nil;
    }
    
    struct sshbuf *blob = sshbuf_from(self.fileBlobData.bytes, self.fileBlobData.length);
    if ( blob == nil ) {
        slog(@"🔴 Could not alloc blob from Key...");
        return nil;
    }
    
    struct sshkey *thePrivateKey = nil;
    int ret = sshkey_parse_private_fileblob(blob, cOriginalPassphrase, &thePrivateKey, NULL);
    sshbuf_free(blob);
    
    if ( ret != SSH_ERR_SUCCESS ) {
        slog(@"🔴 %s", ssh_err(ret));
        return nil;
    }
    
    
    
    struct sshbuf *keyblob = NULL;
    if ((keyblob = sshbuf_new()) == NULL) {
        slog(@"🔴 Could not allocate");
        sshkey_free(thePrivateKey);
        return nil;
    }
    
    ret = sshkey_private_to_fileblob(thePrivateKey, keyblob, cExportPassphrase, "", SSHKEY_PRIVATE_OPENSSH, NULL, 0);
    sshkey_free(thePrivateKey);
    
    if ( ret != SSH_ERR_SUCCESS ) {
        sshbuf_free(keyblob);
        slog(@"🔴 %s", ssh_err(ret));
        return nil;
    }
    
    NSMutableData* data = [NSMutableData dataWithLength:sshbuf_len(keyblob)];
    ret = sshbuf_get(keyblob, data.mutableBytes, data.length);
    sshbuf_free(keyblob);
    
    if ( ret != SSH_ERR_SUCCESS ) {
        slog(@"🔴 %s", ssh_err(ret));
        return nil;
    }
    
    return data;
}

- (NSData *)publicKeySerializationBlob {
    return self.publicKeySerializationBlobBase64.dataFromBase64;
}

- (NSString *)privateKey {
    return [[NSString alloc] initWithData:self.fileBlobData encoding:NSUTF8StringEncoding];
}

- (NSData *)data {
    return self.fileBlobData;
}

- (NSData*)sign:(NSData*)challenge passphrase:(NSString*)passphrase flags:(u_int)flags {
    const char* cPassphrase = [passphrase cStringUsingEncoding:NSUTF8StringEncoding];
    if ( cPassphrase == nil ) {
        slog(@"🔴 sign: Could not get s String passphrase");
        return nil;
    }
    
    struct sshbuf *blob = sshbuf_from(self.fileBlobData.bytes, self.fileBlobData.length);
    if ( blob == NULL ) {
        slog(@"🔴 sign: Could not allocate blob for private key.");
        return nil;
    }
    
    struct sshkey *thePrivateKey = nil;
    int ret = sshkey_parse_private_fileblob(blob, cPassphrase, &thePrivateKey, NULL);
    sshbuf_free(blob);
    
    if ( ret != SSH_ERR_SUCCESS ) {
        slog(@"🔴 Could not parse Private Key...");
        return nil;
    }
    
    
    
    u_char *signature = NULL;
    size_t slen = 0;
    if (sshkey_sign(thePrivateKey, &signature, &slen, challenge.bytes, challenge.length, agent_decode_alg(thePrivateKey, flags), NULL, NULL, 0) != 0) {
        slog(@"🔴 Could not sign the challenge");
        sshkey_free(thePrivateKey);
        return nil;
    }

    NSData* sig = [NSData dataWithBytes:signature length:slen];
    
    free(signature);
    sshkey_free(thePrivateKey);
    
    return sig;
}

- (BOOL)isEqualTo:(id)object {
    if (object == nil) {
        return NO;
    }
    if (self == object) {
        return YES;
    }
    if (![object isKindOfClass:[OpenSSHPrivateKey class]]) {
        return NO;
    }
    
    OpenSSHPrivateKey* other = (OpenSSHPrivateKey*)object;
    
    
    
    if ( ![self.fileBlobData isEqualToData:other.fileBlobData] ) {
        return NO;
    }
    
    return YES;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"%@ (%@)", self.fingerprint, self.type];
}

- (BOOL)validatePassphrase:(nonnull NSString *)passphrase {
    const char* cPassphrase = [passphrase cStringUsingEncoding:NSUTF8StringEncoding];
    if ( cPassphrase == nil ) {
        slog(@"🔴 vaildatePassphrase: Could not get c String passphrase");
        return NO;
    }
    
    struct sshbuf *blob = sshbuf_from(self.fileBlobData.bytes, self.fileBlobData.length);
    if ( blob == nil ) {
        slog(@"🔴 Could not alloc blob from Key...");
        return NO;
    }
    
    int ret = sshkey_parse_private_fileblob(blob, cPassphrase, NULL, NULL);
    sshbuf_free(blob);
    
    if ( ret != SSH_ERR_SUCCESS ) {
        if ( ret == SSH_ERR_KEY_WRONG_PASSPHRASE ) {
            return NO;
        }
        else {
            slog(@"🔴 Could not parse key from blob... %s", ssh_err(ret));
            return NO;
        }
    }
    
    return YES;
}

static char *agent_decode_alg(struct sshkey *key, u_int flags) {
    if (key->type == KEY_RSA) {
        if (flags & SSH_AGENT_RSA_SHA2_256) {
            return "rsa-sha2-256";
        }
        else if (flags & SSH_AGENT_RSA_SHA2_512) {
            return "rsa-sha2-512";
        }
    }
    else if (key->type == KEY_RSA_CERT) {
        if (flags & SSH_AGENT_RSA_SHA2_256) {
            return "rsa-sha2-256-cert-v01@openssh.com";
        }
        else if (flags & SSH_AGENT_RSA_SHA2_512) {
            return "rsa-sha2-512-cert-v01@openssh.com";
        }
    }
    
    return NULL;
}

@end
