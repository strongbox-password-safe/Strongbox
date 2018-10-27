//
//  VariantDictionary.m
//  Strongbox
//
//  Created by Mark on 26/10/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
//

#import "VariantDictionary.h"
#import "BinaryParsingHelper.h"

typedef struct _EntryHeader {
    uint8_t type;
    uint8_t keyLength[4];
    uint8_t keyData[];
} EntryHeader;
#define SIZE_OF_ENTRY_HEADER 5

@implementation VariantDictionary

+ (NSDictionary<NSString*, NSObject*>*)fromData:(NSData*)data {
    //    A VariantDictionary is a key-value dictionary (with the key being a string and the value being an object), which is serialized as follows:
    //
    //    [2 bytes] Version, as UInt16, little-endian, currently 0x0100 (version 1.0). The high byte is critical (i.e. the loading code should refuse to load the data if the high byte is too high), the low byte is informational (i.e. it can be ignored).
    //    [n items] n serialized items (see below).
    //    [1 byte] Null terminator byte.
    //
    //    Each of the n serialized items has the following form:
    //
    //    [1 byte] Value type, can be one of the following:
    //    0x04: UInt32.
    //    0x05: UInt64.
    //    0x08: Bool.
    //    0x0C: Int32.
    //    0x0D: Int64.
    //    0x18: String (UTF-8, without BOM, without null terminator).
    //    0x42: Byte array.
    //    [4 bytes] Length k of the key name in bytes, Int32, little-endian.
    //    [k bytes] Key name (string, UTF-8, without BOM, without null terminator).
    //    [4 bytes] Length v of the value in bytes, Int32, little-endian.
    //    [v bytes] Value. Integers are stored in little-endian encoding, and a Bool is one byte (false = 0, true = 1); the other types are clear.

    NSMutableDictionary<NSString*, NSObject*> *ret = [NSMutableDictionary dictionary];
    
    uint8_t *buffer = (uint8_t*)data.bytes;
    //uint8_t versionMinor = buffer[0];
    uint8_t versionMajor = buffer[1];
    
    // TODO: Bounds checking
    
    if(versionMajor != 1) {
        NSLog(@"Variant Dictionary major version != 1");
        return nil;
    }
    
    EntryHeader* header = (EntryHeader*)&buffer[2];
    
    while(header->type != 0) {
        size_t keyLength = littleEndian4BytesToInt32(header->keyLength);
        NSString* key = getKey(header->keyData, keyLength);
        
        //NSLog(@"Found Variant Dictionary Entry of Type [%d] - [%@]", header->type, key);
        
        if(!key) {
            NSLog(@"Could not get key from Variant Dictionary.");
            return nil;
        }
        
        uint8_t *value = ((uint8_t*)header) + (SIZE_OF_ENTRY_HEADER + keyLength);
        size_t valueLength = littleEndian4BytesToInt32(value);
        
        NSObject* obj = getObject(header->type, value + 4, valueLength);
        
        if(obj) {
            [ret setObject:obj forKey:key];
        }
        
        uint8_t *next = value + (valueLength + 4);
        header = (EntryHeader*)next;
    }
    
    return ret;
}

static NSString* getKey(void* data, size_t length) {
    return [[NSString alloc] initWithBytes:data length:length encoding:NSUTF8StringEncoding];
}

static NSObject* getObject(uint8_t type, void* data, size_t length) {
    switch (type) {
        case 0x04: // UInt32
            return @(littleEndian4BytesToUInt32(data));
            break;
        case 0x05: // UInt64
            return @(littleEndian8BytesToUInt64(data));
            break;
        case 0x0C: // Int32
            return @(littleEndian4BytesToInt32(data));
            break;
        case 0x0D: // Int64
            return @(littleEndian8BytesToInt64(data));
            break;
        case 0x08: // Bool
            return @(*((uint8_t*)data) == 1);
            break;
        case 0x18: // String (UTF-8, without BOM, without null terminator).
            return getKey(data, length);
            break;
        case 0x42: // Byte array.
            return [NSData dataWithBytes:data length:length];
            break;
        default:
            NSLog(@"WARN: Unknown Variant Dictionary Value Type = %d. returning as Data", type);
            return [NSData dataWithBytes:data length:length];
            break;
    }
}

@end
