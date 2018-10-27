//
//  BinaryParsingHelper.m
//  Strongbox-iOS
//
//  Created by Mark on 15/10/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
//

#import "BinaryParsingHelper.h"

@implementation BinaryParsingHelper

+ (void)integerTolittleEndian4Bytes:(int)data bytes:(unsigned char *)b {
    b[0] = (unsigned char)data;
    b[1] = (unsigned char)(((uint)data >> 8) & 0xFF);
    b[2] = (unsigned char)(((uint)data >> 16) & 0xFF);
    b[3] = (unsigned char)(((uint)data >> 24) & 0xFF);
}

NSData* Uint64ToLittleEndianData(uint64_t integer) {
    return UintToLittleEndianData(integer, 8);
}

NSData* Uint32ToLittleEndianData(uint32_t integer) {
    return UintToLittleEndianData(integer, 4);
}

NSData* Uint16ToLittleEndianData(uint16_t integer) {
    return UintToLittleEndianData(integer, 2);
}

NSData* UintToLittleEndianData(uint64_t integer, uint8_t byteCount) {
    NSMutableData *ret = [[NSMutableData alloc] initWithLength:byteCount];
    
    for(int i=0;i<byteCount;i++) {
        ((uint8_t*)ret.mutableBytes)[i] = (uint8_t)(((uint64_t)integer >> (i * 8)) & 0xFF);
    }

    return ret;
}

int64_t littleEndian8BytesToInt64(uint8_t* bytes) {
    return littleEndianNBytesToInt64(bytes, 8);
}

int32_t littleEndian4BytesToInt32(uint8_t* bytes) {
    return (int32_t)littleEndianNBytesToInt64(bytes, 4);
}

int16_t littleEndian2BytesToInt16(uint8_t *bytes) {
    return (int16_t)littleEndianNBytesToInt64(bytes, 2);
}

int64_t littleEndianNBytesToInt64(uint8_t* bytes, int n)  {
    if(n > 8) {
        NSLog(@"n > 8 passed to littleEndianNBytesToInt64");
        return -1;
    }
    
    int64_t ret = 0;

    for (int i=0; i<n; i++) {
        int64_t tmp = bytes[i];
        ret |= tmp << (i*8);
    }

    return ret;
}

uint64_t littleEndian8BytesToUInt64(uint8_t* bytes) {
    return littleEndianNBytesToInt64(bytes, 8);
}

uint32_t littleEndian4BytesToUInt32(uint8_t* bytes) {
    return (int32_t)littleEndianNBytesToInt64(bytes, 4);
}

uint16_t littleEndian2BytesToUInt16(uint8_t *bytes) {
    return (int16_t)littleEndianNBytesToInt64(bytes, 2);
}

uint64_t littleEndianNBytesToUInt64(uint8_t* bytes, int n)  {
    if(n > 8) {
        NSLog(@"n > 8 passed to littleEndianNBytesToUInt64");
        return -1;
    }
    
    uint64_t ret = 0;
    
    for (int i=0; i<n; i++) {
        uint64_t tmp = bytes[i];
        ret |= tmp << (i*8);
    }
    
    return ret;
}

///////////////////////////////////////////////////////////////////////////////////////////////////

void hexdump(unsigned char *buffer, unsigned long index, unsigned long width) {
    unsigned long i;
    
    for (i = 0; i < index; i++) {
        printf("%02x ", buffer[i]);
    }
    
    for (unsigned long spacer = index; spacer < width; spacer++) {
        printf("    ");
    }
    
    printf(": ");
    
    for (i = 0; i < index; i++) {
        if (!isprint(buffer[i])) printf(".");
        else printf("%c", buffer[i]);
    }
    
    printf("\n");
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
