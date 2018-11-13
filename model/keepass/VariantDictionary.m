//
//  VariantDictionary.m
//  Strongbox
//
//  Created by Mark on 26/10/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
//

#import "VariantDictionary.h"
#import "Utils.h"

typedef struct _EntryHeader {
    uint8_t type;
    uint8_t keyLength[4];
    uint8_t keyData[];
} EntryHeader;
#define SIZE_OF_ENTRY_HEADER 5

@implementation VariantDictionary

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

+ (NSData *)toData:(NSDictionary<NSString *,VariantObject *> *)dictionary {
    NSMutableData *ret = [NSMutableData data];
    
    uint8_t version[] = { 0x00, 0x01 };
    [ret appendBytes:version length:2];
    
    NSArray* sortedKeys = [dictionary.allKeys sortedArrayWithOptions:NSSortStable usingComparator:^NSComparisonResult(id  _Nonnull obj1, id  _Nonnull obj2) {
        return [obj1 compare:obj2];
    }];
    
    for (NSString* key in sortedKeys) {
        VariantObject* value = dictionary[key];
        
        // Type
        
        uint8_t type[] = { value.type };
        [ret appendBytes:type length:1];
    
        // Key name length
        
        NSData *keyLengthData = Uint32ToLittleEndianData((uint32_t)key.length);
        [ret appendData:keyLengthData];
    
        // Key Name
        
        NSData* keyNameData = [key dataUsingEncoding:NSUTF8StringEncoding];
        [ret appendData:keyNameData];
        
        // Value Length
        
        uint32_t valueLength = getValueLength(value);
        NSData* valueLengthData = Uint32ToLittleEndianData(valueLength);
        [ret appendData:valueLengthData];
        
        // Value
        
        NSData* valueData = getValueAsData(value);
        [ret appendData:valueData];
    }
    
    uint8_t terminator[] = {0x00};
    [ret appendBytes:terminator length:1];
    return ret;
}

+ (NSDictionary<NSString*, VariantObject*>*)fromData:(NSData*)data {
    NSMutableDictionary<NSString*, VariantObject*> *ret = [NSMutableDictionary dictionary];
    
    uint8_t *buffer = (uint8_t*)data.bytes;
    uint8_t *eof = (uint8_t*)data.bytes + data.length;
    
    if(buffer + 1 > eof) {
        NSLog(@"Not enough data to read Entry header.");
        return nil;
    }
    
    //uint8_t versionMinor = buffer[0];
    uint8_t versionMajor = buffer[1];
    
    if(versionMajor != 1) {
        NSLog(@"Variant Dictionary major version != 1");
        return nil;
    }
    
    EntryHeader* header = (EntryHeader*)&buffer[2];

    while(header->type != 0) {
        size_t keyLength = littleEndian4BytesToInt32(header->keyLength);

        if(header->keyData + keyLength > eof) {
            NSLog(@"Not enough data to read Entry header Key.");
            return nil;
        }
        
        NSString* key = getKey(header->keyData, keyLength);
        
        //NSLog(@"Found Variant Dictionary Entry of Type [%d] - [%@]", header->type, key);
        
        if(!key) {
            NSLog(@"Could not get key from Variant Dictionary.");
            return nil;
        }
        
        uint8_t *value = ((uint8_t*)header) + (SIZE_OF_ENTRY_HEADER + keyLength);
        size_t valueLength = littleEndian4BytesToInt32(value);
        
        if(value + valueLength > eof) {
            NSLog(@"Not enough data to read Entry header value.");
            return nil;
        }
        
        NSObject* theObj = getObject(header->type, value + 4, valueLength);
        VariantObject *obj = [[VariantObject alloc] initWithType:header->type theObject:theObj];
        
        if(obj) {
            [ret setObject:obj forKey:key];
        }
        
        uint8_t *next = value + (valueLength + 4);
        
        if(next + 1 > eof) {
            NSLog(@"Not enough data to read next Entry header Key.");
            return nil;
        }
        
        header = (EntryHeader*)next;
    }
    
    return ret;
}

static NSData* getValueAsData(VariantObject* value) {
    switch (value.type) {
        case kVariantTypeUint32: // UInt32
            return Uint32ToLittleEndianData(((NSNumber*)value.theObject).unsignedIntValue);
            break;
        case kVariantTypeUint64: // UInt64
            return Uint64ToLittleEndianData(((NSNumber*)value.theObject).unsignedLongLongValue);
            break;
        case kVariantTypeInt32: // Int32
            return Int32ToLittleEndianData(((NSNumber*)value.theObject).intValue);
            break;
        case kVariantTypeInt64: // Int64
            return Int64ToLittleEndianData(((NSNumber*)value.theObject).longLongValue);
            break;
        case kVariantTypeBool: // Bool
            {
                uint8_t boolBytes[] = { ((NSNumber*)value.theObject).boolValue };
                return [NSData dataWithBytes:boolBytes length:1]; 
            }
            break;
        case kVariantTypeString: // String (UTF-8, without BOM, without null terminator).
            return [((NSString*)value.theObject) dataUsingEncoding:NSUTF8StringEncoding];
            break;
        case kVariantTypeByteArray: // Byte array.
            return ((NSData*)value.theObject);
            break;
        default:
            NSLog(@"WARN: Unknown Variant Dictionary Value Type = %d. returning as Data", value.type);
            return [NSData data];
            break;
    }
}

static NSObject* getObject(uint8_t type, void* data, size_t length) {
    switch (type) {
        case kVariantTypeUint32: // UInt32
            return [NSNumber numberWithUnsignedInt:littleEndian4BytesToUInt32(data)];
            break;
        case kVariantTypeUint64: // UInt64
            return [NSNumber numberWithUnsignedLongLong:littleEndian8BytesToUInt64(data)];
            break;
        case kVariantTypeInt32: // Int32
            return [NSNumber numberWithInt:littleEndian4BytesToInt32(data)];
            break;
        case kVariantTypeInt64: // Int64
            return [NSNumber numberWithLongLong:littleEndian8BytesToInt64(data)];
            break;
        case kVariantTypeBool: // Bool
            return @(*((uint8_t*)data) == 1);
            break;
        case kVariantTypeString: // String (UTF-8, without BOM, without null terminator).
            return getKey(data, length);
            break;
        case kVariantTypeByteArray: // Byte array.
            return [NSData dataWithBytes:data length:length];
            break;
        default:
            NSLog(@"WARN: Unknown Variant Dictionary Value Type = %d. returning as Data", type);
            return [NSData dataWithBytes:data length:length];
            break;
    }
}

static uint32_t getValueLength(VariantObject* value) {
    switch (value.type) {
        case kVariantTypeInt32:
        case kVariantTypeUint32: // UInt32
            return 4;
            break;
        case kVariantTypeInt64:
        case kVariantTypeUint64: // UInt64
            return 8;
            break;
        case kVariantTypeBool: // Bool
            return 1;
            break;
        case kVariantTypeString: // String (UTF-8, without BOM, without null terminator).
            return (uint32_t)((NSString*)value.theObject).length;
            break;
        case kVariantTypeByteArray: // Byte array.
            return (uint32_t)((NSData*)value.theObject).length;
            break;
        default:
            NSLog(@"WARN: Unknown Variant Dictionary Value Type = %d. returning 0", value.type);
            return 0;
            break;
    }
}

static NSString* getKey(void* data, size_t length) {
    return [[NSString alloc] initWithBytes:data length:length encoding:NSUTF8StringEncoding];
}

@end
