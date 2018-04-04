#import "SafeTools.h"
#import <CommonCrypto/CommonDigest.h>
#import <CommonCrypto/CommonHMAC.h>
#import "twofish/tomcrypt.h"
#import "Record.h"
#import "Field.h"

#include <Security/Security.h>

//#define DEBUG_MEMORY_ALLOCATION_LOGGING

@implementation SafeTools

+ (NSData *)calculateRFC2104Hmac:(NSData *)m key:(NSData *)key {
    unsigned char K[CC_SHA256_BLOCK_BYTES];

    memset(K, 0, CC_SHA256_BLOCK_BYTES);
    [key getBytes:K length:key.length];

    // Get K with iPad

    unsigned char KwithIpad[CC_SHA256_BLOCK_BYTES];

    for (int i = 0; i < CC_SHA256_BLOCK_BYTES; i++) {
        KwithIpad[i] = K[i] ^ 0x36;
    }

    // Get K with oPad

    unsigned char KwithOpad[CC_SHA256_BLOCK_BYTES];

    for (int i = 0; i < CC_SHA256_BLOCK_BYTES; i++) {
        KwithOpad[i] = K[i] ^ 0x5c;
    }

    // Get H(Kipad | m)

    CC_SHA256_CTX context;

    NSMutableData *hKipadAndM = [NSMutableData dataWithLength:CC_SHA256_DIGEST_LENGTH ];

    CC_SHA256_Init(&context);

    NSMutableData *y = [[NSMutableData alloc] initWithBytes:KwithIpad length:CC_SHA256_BLOCK_BYTES];
    [y appendData:m];

    CC_SHA256_Update(&context, y.bytes, (CC_LONG)y.length);
    //CC_SHA256_Update(&context, m.bytes, (CC_LONG)[m length] );

    CC_SHA256_Final(hKipadAndM.mutableBytes, &context);

    // get H(kWithOpad | H(KiPad | m))

    CC_SHA256_CTX context2;

    NSMutableData *hmac = [NSMutableData dataWithLength:CC_SHA256_DIGEST_LENGTH ];

    CC_SHA256_Init(&context2);

    NSMutableData *z = [[NSMutableData alloc] initWithBytes:KwithOpad length:CC_SHA256_BLOCK_BYTES];
    [z appendData:hKipadAndM];

    CC_SHA256_Update(&context2, z.bytes, (CC_LONG)z.length);
    //CC_SHA256_Update(&context2, hKipadAndM.bytes, (CC_LONG)CC_SHA256_DIGEST_LENGTH );

    CC_SHA256_Final(hmac.mutableBytes, &context2);

    return hmac;
}

+ (NSData *)serializeField:(Field *)field {
    FieldHeader header;

    header.length = (int)(field.data).length;
    header.type = field.type;

    // Buffer with length rounded forward to TWOFISH_BLOCKSIZE boundary...

    unsigned int length = (unsigned int)(field.data).length + FIELD_HEADER_LENGTH;

    if (length % TWOFISH_BLOCK_SIZE != 0) {
        int sub = ((unsigned int)length % TWOFISH_BLOCK_SIZE);
        length += TWOFISH_BLOCK_SIZE - sub;
    }

#ifdef DEBUG_MEMORY_ALLOCATION_LOGGING
    NSLog(@"serializeField => Allocating: %lu bytes", (unsigned long)length);
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
    int err;
    symmetric_key cbckey;

    if ((err = twofish_setup(K.bytes, TWOFISH_KEYSIZE_BYTES, 0, &cbckey)) != CRYPT_OK) {
        NSLog(@"Invalid K Key");
        return nil;
    }

    int blockCount = (int)ptData.length / TWOFISH_BLOCK_SIZE;

    NSMutableData *ret = [[NSMutableData alloc] init];
    unsigned char *localIv = iv;

    for (int i = 0; i < blockCount; i++) {
        //NSLog(@"Encrypting Block %d", i);

        unsigned char pt[TWOFISH_BLOCK_SIZE];
        [ptData getBytes:pt range:NSMakeRange(i * TWOFISH_BLOCK_SIZE, TWOFISH_BLOCK_SIZE)];

        // CBC Loop xor with IV or previous CT

        for (int j = 0; j < TWOFISH_BLOCK_SIZE; j++) {
            unsigned char b = localIv[j];
            unsigned char c = (unsigned char)pt[j];
            pt[j] = b ^ c;
        }

        unsigned char ct[TWOFISH_BLOCK_SIZE];
        twofish_ecb_encrypt(pt, ct, &cbckey);

        [ret appendBytes:ct length:TWOFISH_BLOCK_SIZE]; // Write to final buffer

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

    // hdr.salt

    if (SecRandomCopyBytes(kSecRandomDefault, SIZE_OF_PASSWORD_SAFE_3_HEADER_SALT, hdr.salt)) {
        // TODO: return error?
        NSLog(@"Eeek");
    }

    // hdr.iter

    [SafeTools integerTolittleEndian4Bytes:keyStretchIterations bytes:hdr.iter];

    // P' => We generate P' using master password and salt

    NSData *salt = [NSData dataWithBytes:hdr.salt length:SIZE_OF_PASSWORD_SAFE_3_HEADER_SALT];
    NSData *pw = [NSData dataWithData:[masterPassword dataUsingEncoding:NSUTF8StringEncoding]];

    CC_SHA256_CTX context;
    NSMutableData *hash = [NSMutableData dataWithLength:CC_SHA256_DIGEST_LENGTH ];
    CC_SHA256_Init(&context);
    CC_SHA256_Update(&context, pw.bytes, (CC_LONG)pw.length);
    CC_SHA256_Update(&context, salt.bytes, (CC_LONG)salt.length);
    CC_SHA256_Final(hash.mutableBytes, &context);

    NSData *pBarData = [NSData dataWithData:hash];

    for (int i = 0; i < keyStretchIterations; i++) {
        NSData *tmp = [SafeTools sha256:pBarData];
        pBarData = [NSData dataWithData:tmp];
    }

    // hPbar => We now have P' we need H(P') so one more sha256!

    NSData *hPBar = [SafeTools sha256:pBarData];
    [hPBar getBytes:hdr.hPBar length:32];

    // We generate new K and L

    unsigned char k1[TWOFISH_BLOCK_SIZE];
    unsigned char k2[TWOFISH_BLOCK_SIZE];
    unsigned char l1[TWOFISH_BLOCK_SIZE];
    unsigned char l2[TWOFISH_BLOCK_SIZE];

    if (SecRandomCopyBytes(kSecRandomDefault, TWOFISH_BLOCK_SIZE, k1) ||
        SecRandomCopyBytes(kSecRandomDefault, TWOFISH_BLOCK_SIZE, k2) ||
        SecRandomCopyBytes(kSecRandomDefault, TWOFISH_BLOCK_SIZE, l1) ||
        SecRandomCopyBytes(kSecRandomDefault, TWOFISH_BLOCK_SIZE, l2)) {
        // TODO: return error?!
        NSLog(@"Eeek");
    }

    //    NSLog(@"--------------- new ------------------");
    //    hexdump(k1, TWOFISH_BLOCK_SIZE, 16);
    //    hexdump(k2, TWOFISH_BLOCK_SIZE, 16);
    //    hexdump(l1, TWOFISH_BLOCK_SIZE, 16);
    //    hexdump(l2, TWOFISH_BLOCK_SIZE, 16);
    //    NSLog(@"---------------------------------------");

    //    hdr.b1,  hdr.b2, hdr.b3,  hdr.b4;

    int err;
    symmetric_key skey;

    if ((err = twofish_setup(pBarData.bytes, TWOFISH_KEYSIZE_BYTES, 0, &skey)) != CRYPT_OK) {
        // TODO: return error?
        NSLog(@"Eeek");
    }

    twofish_ecb_encrypt(k1, hdr.b1, &skey);
    twofish_ecb_encrypt(k2, hdr.b2, &skey);
    twofish_ecb_encrypt(l1, hdr.b3, &skey);
    twofish_ecb_encrypt(l2, hdr.b4, &skey);

    // we need to return K and L also

    NSMutableData *kk = [[NSMutableData alloc] initWithBytes:k1 length:TWOFISH_BLOCK_SIZE];
    [kk appendBytes:k2 length:TWOFISH_BLOCK_SIZE];

    NSMutableData *ll = [[NSMutableData alloc] initWithBytes:l1 length:TWOFISH_BLOCK_SIZE];
    [ll appendBytes:l2 length:TWOFISH_BLOCK_SIZE];

    *K = kk;
    *L = ll;

    // hdr.iv;

    if (SecRandomCopyBytes(kSecRandomDefault, SIZE_OF_PASSWORD_SAFE_3_HEADER_IV, hdr.iv)) {
        // TODO: return error?
        NSLog(@"Eeek");
    }

    return hdr;
}

+ (PasswordSafe3Header)getHeader:(NSData*)data {
    PasswordSafe3Header ret;
    
    [data getBytes:&ret length:SIZE_OF_PASSWORD_SAFE_3_HEADER];
    
    return ret;
}

+ (BOOL)isAValidSafe:(NSData *)candidate {
    // TODO: Calculate minimum size of a PasswordSafe DB and verify length
    
    PasswordSafe3Header header = [SafeTools getHeader:candidate];
    
    if (header.tag[0] != 'P' ||
        header.tag[1] != 'W' ||
        header.tag[2] != 'S' ||
        header.tag[3] != '3') {
        NSLog(@"No PWS3 magic");
        return NO;
    }

    NSUInteger endOfData = [SafeTools getEofFileOffset:candidate];
    
    if (endOfData == NSNotFound) {
        NSLog(@"No End of File marker magic");
        return NO;
    }

    NSUInteger recordsLength = endOfData - SIZE_OF_PASSWORD_SAFE_3_HEADER;
    if (recordsLength <= 0) {
        NSLog(@"Negative or zero record length");
        return NO;
    }

    NSInteger numBlocks = recordsLength / TWOFISH_BLOCK_SIZE;

    if (numBlocks <= 0) {
        NSLog(@"Zero blocks?! Eeek");
        return NO;
    }

    NSUInteger rem = recordsLength % TWOFISH_BLOCK_SIZE;

    if (rem != 0) {
        NSLog(@"Non zero remainder in blocks?! Eeek");
        return NO;
    }

    return YES;
}

+ (NSInteger)getNumberOfBlocks:(NSData*)candidate {
    NSUInteger endOfData = [SafeTools getEofFileOffset:candidate];
    
    if (endOfData == NSNotFound) {
        NSLog(@"No End of File marker magic");
        return NO;
    }
    
    NSUInteger recordsLength = endOfData - SIZE_OF_PASSWORD_SAFE_3_HEADER;
    if (recordsLength <= 0) {
        NSLog(@"Negative or zero record length");
        return NO;
    }
    
    return recordsLength / TWOFISH_BLOCK_SIZE;
}

+ (NSInteger)getKeyStretchIterations:(NSData *)data {
    PasswordSafe3Header header = [SafeTools getHeader:data];
    return [SafeTools littleEndian4BytesToInteger:header.iter];
}

+ (NSUInteger)getEofFileOffset:(NSData*)data {
    // TODO: Out of bounds checking
    
    NSData *endMarker = [EOF_MARKER dataUsingEncoding:NSUTF8StringEncoding];
    NSRange endRange = [data rangeOfData:endMarker options:NSDataSearchBackwards range:NSMakeRange(0, data.length)];
    
    return endRange.location;
}

+ (void)doStretchKeyCompution:(int)iter header:(PasswordSafe3Header *)pHeader pBar_p:(NSData **)ppBar hPBar_p:(NSData **)hPBar_p password:(NSString *)password {
    //NSLog(@"Keystretch Iterations: %d", iter);

    // Do the keystretch to verify password

    NSData *salt = [NSData dataWithBytes:pHeader->salt length:32];
    NSData *pw = [NSData dataWithData:[password dataUsingEncoding:NSUTF8StringEncoding]];

    // MMcG
    // For some reason appending the password and salt bytes together and doing a sha256 on them
    // in one pass doesn't work. Must Initialize, update, update, final to get correct result...

    CC_SHA256_CTX context;
    NSMutableData *hash = [NSMutableData dataWithLength:CC_SHA256_DIGEST_LENGTH ];

    CC_SHA256_Init(&context);
    CC_SHA256_Update(&context, pw.bytes, (CC_LONG)pw.length);
    CC_SHA256_Update(&context, salt.bytes, (CC_LONG)salt.length);
    CC_SHA256_Final(hash.mutableBytes, &context);

    *ppBar = [NSData dataWithData:hash];

    for (int i = 0; i < iter; i++) {
        NSData *tmp = [SafeTools sha256:*ppBar];
        *ppBar = [NSData dataWithData:tmp];
    }

    // We now have P' we need H(P') so one more sha256!

    *hPBar_p = [SafeTools sha256:*ppBar];
}

+ (BOOL)getKandL:(NSData *)pBar header:(PasswordSafe3Header)header K_p:(NSData **)K_p L_p:(NSData **)L_p {
    /* schedule the key */

    int err;
    symmetric_key skey;
    unsigned char *key = (unsigned char *)pBar.bytes;

    if ((err = twofish_setup(key, TWOFISH_KEYSIZE_BYTES, 0, &skey)) != CRYPT_OK) {
        NSLog(@"Crypto Problem");
        return NO;
    }

    NSMutableData *k1 = [NSMutableData dataWithLength:16 ];
    twofish_ecb_decrypt(header.b1, k1.mutableBytes, &skey);
    NSMutableData *k2 = [NSMutableData dataWithLength:16 ];
    twofish_ecb_decrypt(header.b2, k2.mutableBytes, &skey);

    [k1 appendData:k2];
    *K_p = [NSData dataWithData:k1];

    // L

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

+ (void)integerTolittleEndian4Bytes:(int)data bytes:(unsigned char *)b {
    b[0] = (unsigned char)data;
    b[1] = (unsigned char)(((uint)data >> 8) & 0xFF);
    b[2] = (unsigned char)(((uint)data >> 16) & 0xFF);
    b[3] = (unsigned char)(((uint)data >> 24) & 0xFF);
}

+ (int)littleEndian4BytesToInteger:(unsigned char *)bytes {
    int ret =  (bytes[3] << 24)
        |   (bytes[2] << 16)
        |   (bytes[1] << 8)
        |    bytes[0];

    return ret;
}

+ (BOOL)checkPassword:(PasswordSafe3Header *)pHeader password:(NSString *)password pBar:(NSData **)ppBar {
    int iter;

    iter = [self littleEndian4BytesToInteger:pHeader->iter];

    NSData *hPBar;

    [self doStretchKeyCompution:iter header:pHeader pBar_p:ppBar hPBar_p:&hPBar password:password];

    NSData *actualHash = [NSData dataWithBytes:pHeader->hPBar length:32];

    //NSLog(@"%@ => %@", actualHash, hPBar);

    if (![hPBar isEqualToData:actualHash]) {
        return NO;
    }

    return YES;
}

+ (NSData *)decryptBlocks:(NSData *)K ct:(unsigned char *)ct iv:(unsigned char *)iv numBlocks:(NSUInteger)numBlocks {
    int err;
    symmetric_key skey;
    unsigned char *key = (unsigned char *)K.bytes;

    if ((err = twofish_setup(key, TWOFISH_KEYSIZE_BYTES, 0, &skey)) != CRYPT_OK) {
        NSLog(@"Invalid K Key");
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
    //hexdump(raw, [decData length], 2);

    NSLog(@"-------------------------- HEADER -------------------------------");

    for (Field *field in headerFields) {
        //NSData *value = field.data;
        NSString *valueStr = field.prettyDataString;
        NSString *keyStr = field.prettyTypeString;

        //NSLog(@"%@ => %@ => bytes[%@]", keyStr, valueStr, value);
        NSLog(@"%@ => %@", keyStr, valueStr);
    }

    NSLog(@"----------------------------------------------------------------");

    NSLog(@"------------------------- RECORDS ------------------------------");

    for (Record *record in records) {
        for (Field *field in [record getAllFields]) {
            //NSData *value = field.data;
            NSString *valueStr = field.prettyDataString;
            NSString *keyStr = field.prettyTypeString;

            //NSLog(@"%@ => %@ => bytes[%@]", keyStr, valueStr, value);
            NSLog(@"%@ => %@", keyStr, valueStr);
        }

        NSLog(@"----------------------------------------------------------------");
    }
}

+ (NSData *)extractDbHeaderAndRecords:(NSData *)decData
                       headerFields_p:(NSMutableArray **)headerFields_p
                            records_p:(NSMutableArray **)records_p {
    NSMutableData *dataForHmac = [[NSMutableData alloc] init];

#ifdef DEBUG_MEMORY_ALLOCATION_LOGGING
    NSLog(@"extractDbHeaderAndRecords => Allocating: %lu bytes", (unsigned long)decData.length);
#endif
    unsigned char *raw = malloc(decData.length);
    if (!raw)
    {
        return nil;
    }
    
    [decData getBytes:raw length:decData.length];

    //hexdump(raw, [decData length], 16);

    unsigned char *currentField = raw;
    unsigned char *end = raw + decData.length;

    BOOL hdrDone = NO;
    *records_p = [[NSMutableArray alloc] init];
    *headerFields_p = [[NSMutableArray alloc] init];
    NSMutableDictionary *fields = [[NSMutableDictionary alloc] init];

    while (currentField < end) {
        FieldHeader *fieldStart = (FieldHeader *)currentField;

        [Field prettyTypeString:fieldStart->type isHeaderField:!hdrDone];
        
#ifdef DEBUG_READING
        NSLog(@"Reading Field %@ (%d)",
              [Field prettyTypeString:fieldStart->type isHeaderField:!hdrDone], fieldStart->length);
#endif

        [dataForHmac appendBytes:&(fieldStart->data) length:fieldStart->length];

        if (hdrDone) {
            Field *field = [[Field alloc] initWithData:[NSData dataWithBytes:(&fieldStart->data)
                                                                      length:fieldStart->length]
                                                  type:fieldStart->type];

            if (fieldStart->type == FIELD_TYPE_END) {
                Record *newRecord = [[Record alloc]initWithFields:fields];
#ifdef DEBUG_READING
                NSLog(@"Got Record: Title = %@", newRecord.title);
#endif
                [*records_p addObject:newRecord];

                fields = [[NSMutableDictionary alloc] init];
            }
            else {
                NSNumber *type = [NSNumber numberWithInt:fieldStart->type];
                fields[type] = field;
                // OK to use dictionary as only one field per type, unlike header, where empty group can be present multiple times
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

///////////////////////////////////////////////////////////////////////////////////////////////////

void hexdump(unsigned char *buffer, unsigned long index, unsigned long width) {
    unsigned long i;

    for (i = 0; i < index; i++) {
        printf("%02x ", buffer[i]);
    }

    for (unsigned long spacer = index; spacer < width; spacer++) {
        printf("	");
    }

    printf(": ");

    for (i = 0; i < index; i++) {
        if (!isprint(buffer[i])) printf(".");
        else printf("%c", buffer[i]);
    }

    printf("\n");
}

+ (NSData *)sha256:(NSData *)keyData {
    uint8_t digest[CC_SHA256_DIGEST_LENGTH] = { 0 };

    CC_SHA256(keyData.bytes, (CC_LONG)keyData.length, digest);

    NSData *out = [NSData dataWithBytes:digest length:CC_SHA256_DIGEST_LENGTH];

    return out;
}

+ (NSString *)hexadecimalString:(NSData *)data {
    const unsigned char *dataBuffer = (const unsigned char *)data.bytes;

    if (!dataBuffer) {
        return [NSString string];
    }

    NSUInteger dataLength = data.length;
    NSMutableString *hexString = [NSMutableString stringWithCapacity:(dataLength * 2)];

    for (int i = 0; i < dataLength; ++i) {
        [hexString appendString:[NSString stringWithFormat:@"%02lX", (unsigned long)dataBuffer[i]]];
    }

    return [NSString stringWithString:hexString];
}

@end
