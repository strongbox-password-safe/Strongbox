//
//  BinaryParsingHelper.h
//  Strongbox-iOS
//
//  Created by Mark on 15/10/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
//

#if TARGET_OS_IPHONE
#import <UIKit/UIKit.h>
#else
#import <Foundation/Foundation.h>
#endif

NS_ASSUME_NONNULL_BEGIN

@interface BinaryParsingHelper : NSObject

+ (void)integerTolittleEndian4Bytes:(int)data bytes:(unsigned char *)b;

NSData* Uint64ToLittleEndianData(uint64_t integer);
NSData* Uint32ToLittleEndianData(uint32_t integer);
NSData* Uint16ToLittleEndianData(uint16_t integer);

int64_t littleEndian8BytesToInt64(uint8_t* bytes);
int32_t littleEndian4BytesToInt32(uint8_t* bytes);
int16_t littleEndian2BytesToInt16(uint8_t *bytes);
int64_t littleEndianNBytesToInt64(uint8_t* bytes, int n);

uint64_t littleEndian8BytesToUInt64(uint8_t* bytes);
uint32_t littleEndian4BytesToUInt32(uint8_t* bytes);
uint16_t littleEndian2BytesToUInt16(uint8_t *bytes);

void hexdump(unsigned char *buffer, unsigned long index, unsigned long width);
+ (NSString *)hexadecimalString:(NSData *)data;

@end

NS_ASSUME_NONNULL_END
