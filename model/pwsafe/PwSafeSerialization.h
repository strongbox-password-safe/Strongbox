//
//  SafeTools.h
//  StrongBox
//
//  Created by Mark McGuill on 05/06/2014.
//  Copyright (c) 2014 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Field.h"

#define SIZE_OF_PASSWORD_SAFE_3_HEADER      152
#define SIZE_OF_PASSWORD_SAFE_3_HEADER_IV   16
#define SIZE_OF_PASSWORD_SAFE_3_HEADER_SALT 32
#define TWOFISH_BLOCK_SIZE                  16
#define EOF_MARKER                          @"PWS3-EOFPWS3-EOF"
#define DEFAULT_KEYSTRETCH_ITERATIONS       8192
#define TWOFISH_KEYSIZE_BYTES               32
#define FIELD_HEADER_LENGTH                 5


typedef struct _PasswordSafe3Header {
    char tag[4];
    unsigned char salt[32];
    unsigned char iter[4];
    unsigned char hPBar[32];
    unsigned char b1[16];
    unsigned char b2[16];
    unsigned char b3[16];
    unsigned char b4[16];
    unsigned char iv[16];   
} PasswordSafe3Header;

typedef struct _FieldHeader {
    uint32_t length;
    unsigned char type;
    unsigned char data;
} FieldHeader;

NS_ASSUME_NONNULL_BEGIN

@interface PwSafeSerialization : NSObject

+ (BOOL)isValidDatabase:(NSData *)prefix error:(NSError *__autoreleasing  _Nullable *)error;
+ (PasswordSafe3Header)getHeader:(NSData*)data;
+ (NSUInteger)getKeyStretchIterations:(NSData*)data;
+ (NSInteger)getNumberOfBlocks:(NSData*)candidate;
+ (PasswordSafe3Header)generateNewHeader:(int)keyStretchIterations masterPassword:(NSString *)masterPassword K:(NSData *_Nonnull*_Nonnull)K L:(NSData *_Nonnull*_Nonnull)L;
+ (nullable NSData *)serializeField:(Field *)field;
+ (nullable NSData *)encryptCBC:(NSData *)K ptData:(NSData *)ptData iv:(unsigned char *)iv;
+ (NSData *)calculateRFC2104Hmac:(NSData *)m key:(NSData *)key;
+ (BOOL)checkPassword:(PasswordSafe3Header *)pHeader password:(NSString *)password pBar:(NSData *_Nonnull*_Nonnull)ppBar;
+ (BOOL)getKandL:(NSData *)pBar header:(PasswordSafe3Header)header K_p:(NSData *_Nonnull*_Nonnull)K_p L_p:(NSData *_Nonnull*_Nonnull)L_p;
+ (nullable NSMutableData *)decryptBlocks:(NSData *)K ct:(unsigned char *)ct iv:(unsigned char *)iv numBlocks:(NSUInteger)numBlocks;
+ (nullable NSData *)extractDbHeaderAndRecords:(NSData *)decData headerFields_p:(NSMutableArray *_Nonnull*_Nonnull)headerFields_p records_p:(NSMutableArray *_Nonnull*_Nonnull)records_p;
+ (void)dumpDbHeaderAndRecords:(NSMutableArray *)headerFields records:(NSMutableArray *)records;

@end

NS_ASSUME_NONNULL_END
