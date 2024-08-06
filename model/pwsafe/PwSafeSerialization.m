#import "PwSafeSerialization.h"
#import <CommonCrypto/CommonDigest.h>
#import <CommonCrypto/CommonHMAC.h>
#import "twofish/tomcrypt.h"
#import "Record.h"
#import "Field.h"
#import "Utils.h"
#import "NSData+Extensions.h"

#include <Security/Security.h>

//#define DEBUG_MEMORY_ALLOCATION_LOGGING

@implementation PwSafeSerialization

+ (NSData *)calculateRFC2104Hmac:(NSData *)m key:(NSData *)key {
    unsigned char K[CC_SHA256_BLOCK_BYTES];

    memset(K, 0, CC_SHA256_BLOCK_BYTES);
    [key getBytes:K length:key.length];

    

    unsigned char KwithIpad[CC_SHA256_BLOCK_BYTES];

    for (int i = 0; i < CC_SHA256_BLOCK_BYTES; i++) {
        KwithIpad[i] = K[i] ^ 0x36;
    }

    

    unsigned char KwithOpad[CC_SHA256_BLOCK_BYTES];

    for (int i = 0; i < CC_SHA256_BLOCK_BYTES; i++) {
        KwithOpad[i] = K[i] ^ 0x5c;
    }

    

    CC_SHA256_CTX context;

    NSMutableData *hKipadAndM = [NSMutableData dataWithLength:CC_SHA256_DIGEST_LENGTH ];

    CC_SHA256_Init(&context);

    NSMutableData *y = [[NSMutableData alloc] initWithBytes:KwithIpad length:CC_SHA256_BLOCK_BYTES];
    [y appendData:m];

    CC_SHA256_Update(&context, y.bytes, (CC_LONG)y.length);
    

    CC_SHA256_Final(hKipadAndM.mutableBytes, &context);

    

    CC_SHA256_CTX context2;

    NSMutableData *hmac = [NSMutableData dataWithLength:CC_SHA256_DIGEST_LENGTH ];

    CC_SHA256_Init(&context2);

    NSMutableData *z = [[NSMutableData alloc] initWithBytes:KwithOpad length:CC_SHA256_BLOCK_BYTES];
    [z appendData:hKipadAndM];

    CC_SHA256_Update(&context2, z.bytes, (CC_LONG)z.length);
    

    CC_SHA256_Final(hmac.mutableBytes, &context2);

    return hmac;
}

+ (NSData *)serializeField:(Field *)field {
    FieldHeader header;

    header.length = (uint32_t)(field.data).length;
    header.type = field.type;

    

    unsigned int length = (unsigned int)(field.data).length + FIELD_HEADER_LENGTH;

    if (length % TWOFISH_BLOCK_SIZE != 0) {
        int sub = ((unsigned int)length % TWOFISH_BLOCK_SIZE);
        length += TWOFISH_BLOCK_SIZE - sub;
    }

#ifdef DEBUG_MEMORY_ALLOCATION_LOGGING
    slog(@"serializeField => Allocating: %lu bytes", (unsigned long)length);
#endif
    unsigned char *buf = malloc(length);
    if(!buf)
    {
        return nil;
    }
    
    if (SecRandomCopyBytes(kSecRandomDefault, length, buf)) {
        free(buf);
        return nil;
    }

    memcpy(buf, &header, FIELD_HEADER_LENGTH);
    [field.data getBytes:&buf[FIELD_HEADER_LENGTH] length:length];
    NSData *data = [[NSData alloc] initWithBytes:buf length:length];

    free(buf);
        
    return data;
}

+ (NSData *)encryptCBC:(NSData *)K ptData:(NSData *)ptData iv:(unsigned char *)iv {
    
    symmetric_key cbckey;

    if ((twofish_setup(K.bytes, TWOFISH_KEYSIZE_BYTES, 0, &cbckey)) != CRYPT_OK) {
        slog(@"Invalid K Key");
        return nil;
    }

    int blockCount = (int)ptData.length / TWOFISH_BLOCK_SIZE;

    NSMutableData *ret = [[NSMutableData alloc] init];
    unsigned char *localIv = iv;
    unsigned char ct[TWOFISH_BLOCK_SIZE];

    for (int i = 0; i < blockCount; i++) {
        

        unsigned char pt[TWOFISH_BLOCK_SIZE];
        [ptData getBytes:pt range:NSMakeRange(i * TWOFISH_BLOCK_SIZE, TWOFISH_BLOCK_SIZE)];

        

        for (int j = 0; j < TWOFISH_BLOCK_SIZE; j++) {
            unsigned char b = localIv[j];
            unsigned char c = (unsigned char)pt[j];
            pt[j] = b ^ c;
        }

        twofish_ecb_encrypt(pt, ct, &cbckey);

        [ret appendBytes:ct length:TWOFISH_BLOCK_SIZE]; 

        localIv = ct;
    }

    return ret;
}

+ (PasswordSafe3Header)generateNewHeader:(int)keyStretchIterations
                          masterPassword:(NSString *)masterPassword
                                       K:(NSData **)K
                                       L:(NSData **)L {
    PasswordSafe3Header hdr;

    hdr.tag[0] = 'P';
    hdr.tag[1] = 'W';
    hdr.tag[2] = 'S';
    hdr.tag[3] = '3';

    

    if (SecRandomCopyBytes(kSecRandomDefault, SIZE_OF_PASSWORD_SAFE_3_HEADER_SALT, hdr.salt)) {
        slog(@"Could not securely copy header salt bytes");
        [Utils createNSError:@"Could not securely copy header salt bytes" errorCode:-1];
    }

    

    [Utils integerTolittleEndian4Bytes:keyStretchIterations bytes:hdr.iter];

    

    NSData *salt = [NSData dataWithBytes:hdr.salt length:SIZE_OF_PASSWORD_SAFE_3_HEADER_SALT];
    NSData *pw = [NSData dataWithData:[masterPassword dataUsingEncoding:NSUTF8StringEncoding]];

    CC_SHA256_CTX context;
    
    uint8_t digest[CC_SHA256_DIGEST_LENGTH] = { 0 };

    CC_SHA256_Init(&context);
    CC_SHA256_Update(&context, pw.bytes, (CC_LONG)pw.length);
    CC_SHA256_Update(&context, salt.bytes, (CC_LONG)salt.length);
    CC_SHA256_Final(digest, &context);

    for (int i = 0; i < keyStretchIterations; i++) {
        CC_SHA256(digest, CC_SHA256_DIGEST_LENGTH, digest);
    }
    NSData* pBarData = [NSData dataWithBytes:digest length:CC_SHA256_DIGEST_LENGTH];
    
    

    NSData *hPBar = pBarData.sha256;
    [hPBar getBytes:hdr.hPBar length:32];

    

    unsigned char k1[TWOFISH_BLOCK_SIZE];
    unsigned char k2[TWOFISH_BLOCK_SIZE];
    unsigned char l1[TWOFISH_BLOCK_SIZE];
    unsigned char l2[TWOFISH_BLOCK_SIZE];

    if (SecRandomCopyBytes(kSecRandomDefault, TWOFISH_BLOCK_SIZE, k1) ||
        SecRandomCopyBytes(kSecRandomDefault, TWOFISH_BLOCK_SIZE, k2) ||
        SecRandomCopyBytes(kSecRandomDefault, TWOFISH_BLOCK_SIZE, l1) ||
        SecRandomCopyBytes(kSecRandomDefault, TWOFISH_BLOCK_SIZE, l2)) {
        slog(@"Could not securely copy K or L bytes");
        [Utils createNSError:@"Could not securely copy K or L bytes" errorCode:-1];
    }

    
    
    
    
    
    

    

    int err;
    symmetric_key skey;

    if ((err = twofish_setup(pBarData.bytes, TWOFISH_KEYSIZE_BYTES, 0, &skey)) != CRYPT_OK) {
        slog(@"Could not do twofish_setup ok: %d", err);
        [Utils createNSError:@"Could not do twofish_setup ok" errorCode:err];
    }

    twofish_ecb_encrypt(k1, hdr.b1, &skey);
    twofish_ecb_encrypt(k2, hdr.b2, &skey);
    twofish_ecb_encrypt(l1, hdr.b3, &skey);
    twofish_ecb_encrypt(l2, hdr.b4, &skey);

    

    NSMutableData *kk = [[NSMutableData alloc] initWithBytes:k1 length:TWOFISH_BLOCK_SIZE];
    [kk appendBytes:k2 length:TWOFISH_BLOCK_SIZE];

    NSMutableData *ll = [[NSMutableData alloc] initWithBytes:l1 length:TWOFISH_BLOCK_SIZE];
    [ll appendBytes:l2 length:TWOFISH_BLOCK_SIZE];

    *K = kk;
    *L = ll;

    

    if (SecRandomCopyBytes(kSecRandomDefault, SIZE_OF_PASSWORD_SAFE_3_HEADER_IV, hdr.iv)) {
        slog(@"Could not do securely copy password safe header ok");
        [Utils createNSError:@"Could not do securely copy Password Safe 3 header ok" errorCode:-1];
    }

    return hdr;
}

+ (PasswordSafe3Header)getHeader:(NSData*)data {
    PasswordSafe3Header ret;
        
    [data getBytes:&ret length:SIZE_OF_PASSWORD_SAFE_3_HEADER];
    
    return ret;
}

+ (BOOL)isValidDatabase:(NSData *)prefix error:(NSError *__autoreleasing  _Nullable *)error {
    if(prefix == nil || prefix.length < SIZE_OF_PASSWORD_SAFE_3_HEADER) {
        return NO;
    }
    
    PasswordSafe3Header header = [PwSafeSerialization getHeader:prefix];
    
    if (header.tag[0] != 'P' ||
        header.tag[1] != 'W' ||
        header.tag[2] != 'S' ||
        header.tag[3] != '3') {
        if(error) {
            *error = [Utils createNSError:@"NO PWS3" errorCode:-1];
        }
        
        return NO;
    }






















    return YES;
}

+ (NSInteger)getNumberOfBlocks:(NSData*)candidate {
    NSUInteger endOfData = [PwSafeSerialization getEofFileOffset:candidate];
    
    if (endOfData == NSNotFound) {
        slog(@"No End of File marker magic");
        return NO;
    }
    
    NSUInteger recordsLength = endOfData - SIZE_OF_PASSWORD_SAFE_3_HEADER;
    if (recordsLength <= 0) {
        slog(@"Negative or zero record length");
        return NO;
    }
    
    return recordsLength / TWOFISH_BLOCK_SIZE;
}

+ (NSUInteger)getKeyStretchIterations:(NSData *)data {
    PasswordSafe3Header header = [PwSafeSerialization getHeader:data];
    return littleEndian4BytesToUInt32(header.iter);
}

+ (NSUInteger)getEofFileOffset:(NSData*)data {
    NSData *endMarker = [EOF_MARKER dataUsingEncoding:NSUTF8StringEncoding];
    NSRange endRange = [data rangeOfData:endMarker options:NSDataSearchBackwards range:NSMakeRange(0, data.length)];
    
    return endRange.location;
}

+ (NSData*)keystretch:(uint32_t)iter header:(unsigned char[32])saltBytes pBar_p:(NSData **)ppBar password:(NSString *)password {
    NSData *pw = [NSData dataWithData:[password dataUsingEncoding:NSUTF8StringEncoding]];

    uint8_t digest[CC_SHA256_DIGEST_LENGTH] = { 0 };

    CC_SHA256_CTX context;
    CC_SHA256_Init(&context);
    CC_SHA256_Update(&context, pw.bytes, (CC_LONG)pw.length);
    CC_SHA256_Update(&context, saltBytes, (CC_LONG)32);
    CC_SHA256_Final(digest, &context);

    for (uint32_t i=0; i<iter; i++) {
        CC_SHA256(digest, CC_SHA256_DIGEST_LENGTH, digest);
    }
    
    *ppBar = [NSData dataWithBytes:digest length:CC_SHA256_DIGEST_LENGTH];
    
    

    return (*ppBar).sha256;
}

+ (BOOL)getKandL:(NSData *)pBar header:(PasswordSafe3Header)header K_p:(NSData **)K_p L_p:(NSData **)L_p {
    /* schedule the key */

    
    symmetric_key skey;
    unsigned char *key = (unsigned char *)pBar.bytes;

    if ((twofish_setup(key, TWOFISH_KEYSIZE_BYTES, 0, &skey)) != CRYPT_OK) {
        slog(@"Crypto Problem");
        return NO;
    }

    NSMutableData *k1 = [NSMutableData dataWithLength:16 ];
    twofish_ecb_decrypt(header.b1, k1.mutableBytes, &skey);
    NSMutableData *k2 = [NSMutableData dataWithLength:16 ];
    twofish_ecb_decrypt(header.b2, k2.mutableBytes, &skey);

    [k1 appendData:k2];
    *K_p = [NSData dataWithData:k1];

    

    NSMutableData *l1 = [NSMutableData dataWithLength:16 ];
    twofish_ecb_decrypt(header.b3, l1.mutableBytes, &skey);
    NSMutableData *l2 = [NSMutableData dataWithLength:16 ];
    twofish_ecb_decrypt(header.b4, l2.mutableBytes, &skey);

    [l1 appendData:l2];
    *L_p = [NSData dataWithData:l1];

    return YES;
}

+ (void)readCbcBlock:(symmetric_key *)skey_p ct:(unsigned char *)ct pt:(unsigned char *)pt iv:(unsigned char *)iv {
    unsigned char ptBar[16];

    twofish_ecb_decrypt(ct, ptBar, &(*skey_p));

    for (int i = 0; i < TWOFISH_BLOCK_SIZE; i++) {
        unsigned char b = ((unsigned char *)ptBar)[i];
        unsigned char c = (unsigned char)iv[i];
        pt[i] = b ^ c;
    }
}

+ (BOOL)checkPassword:(PasswordSafe3Header *)pHeader password:(NSString *)password pBar:(NSData **)ppBar {
    uint32_t iter = littleEndian4BytesToUInt32(pHeader->iter);

    NSData *hPBar = [self keystretch:iter header:pHeader->salt pBar_p:ppBar password:password];

    NSData *actualHash = [NSData dataWithBytes:pHeader->hPBar length:32];

    if (![hPBar isEqualToData:actualHash]) {
        return NO;
    }

    return YES;
}

+ (NSData *)decryptBlocks:(NSData *)K ct:(unsigned char *)ct iv:(unsigned char *)iv numBlocks:(NSUInteger)numBlocks {
    
    symmetric_key skey;
    unsigned char *key = (unsigned char *)K.bytes;

    if ((twofish_setup(key, TWOFISH_KEYSIZE_BYTES, 0, &skey)) != CRYPT_OK) {
        slog(@"Invalid K Key");
        return nil;
    }

    NSMutableData *decData = [[NSMutableData alloc] init];

    unsigned char ivForThisBlock[TWOFISH_BLOCK_SIZE];
    memcpy(ivForThisBlock, iv, TWOFISH_BLOCK_SIZE);
    unsigned char pt[TWOFISH_BLOCK_SIZE];

    for (int i = 0; i < numBlocks; i++) {
        [self readCbcBlock:&skey ct:ct pt:pt iv:ivForThisBlock];
        [decData appendBytes:pt length:TWOFISH_BLOCK_SIZE];

        memcpy(ivForThisBlock, ct, TWOFISH_BLOCK_SIZE);
        ct += TWOFISH_BLOCK_SIZE;
    }

    return [NSData dataWithData:decData];
}

+ (void)dumpDbHeaderAndRecords:(NSMutableArray *)headerFields records:(NSMutableArray *)records {
    

    slog(@"-------------------------- HEADER -------------------------------");

    for (Field *field in headerFields) {
        
        NSString *valueStr = field.prettyDataString;
        NSString *keyStr = field.prettyTypeString;

        
        slog(@"%@ => %@", keyStr, valueStr);
    }

    slog(@"----------------------------------------------------------------");

    slog(@"------------------------- RECORDS ------------------------------");

    for (Record *record in records) {
        for (Field *field in [record getAllFields]) {
            
            NSString *valueStr = field.prettyDataString;
            NSString *keyStr = field.prettyTypeString;

            
            slog(@"%@ => %@", keyStr, valueStr);
        }

        slog(@"----------------------------------------------------------------");
    }
}

+ (NSData *)extractDbHeaderAndRecords:(NSData *)decData
                       headerFields_p:(NSMutableArray **)headerFields_p
                            records_p:(NSMutableArray **)records_p {
    NSMutableData *dataForHmac = [[NSMutableData alloc] init];

#ifdef DEBUG_MEMORY_ALLOCATION_LOGGING
    slog(@"extractDbHeaderAndRecords => Allocating: %lu bytes", (unsigned long)decData.length);
#endif
    unsigned char *raw = malloc(decData.length);
    if (!raw)
    {
        return nil;
    }
    
    [decData getBytes:raw length:decData.length];

    

    unsigned char *currentField = raw;
    unsigned char *end = raw + decData.length;

    BOOL hdrDone = NO;
    *records_p = [[NSMutableArray alloc] init];
    *headerFields_p = [[NSMutableArray alloc] init];
    NSMutableDictionary *fields = [[NSMutableDictionary alloc] init];

    while (currentField < end) {
        FieldHeader *fieldStart = (FieldHeader *)currentField;

        [dataForHmac appendBytes:&(fieldStart->data) length:fieldStart->length];

        if (hdrDone) {
            Field *field = [[Field alloc] initWithData:[NSData dataWithBytes:(&fieldStart->data)
                                                                      length:fieldStart->length]
                                                  type:fieldStart->type];

            if (fieldStart->type == FIELD_TYPE_END) {
                Record *newRecord = [[Record alloc] initWithFields:fields];
                
                [*records_p addObject:newRecord];

                fields = [[NSMutableDictionary alloc] init];
            }
            else {
                NSNumber *type = [NSNumber numberWithInt:fieldStart->type];
                fields[type] = field;
                
            }
        }
        else {
            Field *field = [[Field alloc] initNewDbHeaderField:fieldStart->type withData:[NSData dataWithBytes:(&fieldStart->data) length:fieldStart->length]];

            if (fieldStart->type == HDR_END) {
                hdrDone = YES;
            }
            else {
                [*headerFields_p addObject:field];
            }
        }

        int add = (fieldStart->length + FIELD_HEADER_LENGTH);

        if (add % TWOFISH_BLOCK_SIZE != 0) {
            int sub = add % TWOFISH_BLOCK_SIZE;
            add += TWOFISH_BLOCK_SIZE - sub;
        }

        currentField += add;
    }

    free(raw);

    return dataForHmac;
}

@end
