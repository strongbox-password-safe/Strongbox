//
//  VariantDictionary.m
//  Strongbox
//
//  Created by Mark on 26/10/2018.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
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






















+ (NSData *)toData:(NSDictionary<NSString *,VariantObject *> *)dictionary {
    NSMutableData *ret = [NSMutableData data];
    
    uint8_t version[] = { 0x00, 0x01 };
    [ret appendBytes:version length:2];
    
    NSArray* sortedKeys = [dictionary.allKeys sortedArrayWithOptions:NSSortStable usingComparator:^NSComparisonResult(id  _Nonnull obj1, id  _Nonnull obj2) {
        return [obj1 compare:obj2];
    }];
    
    for (NSString* key in sortedKeys) {
        VariantObject* value = dictionary[key];
        
        
        
        uint8_t type[] = { value.type };
        [ret appendBytes:type length:1];
    
        
        
        NSData *keyLengthData = Uint32ToLittleEndianData((uint32_t)key.length);
        [ret appendData:keyLengthData];
    
        
        
        NSData* keyNameData = [key dataUsingEncoding:NSUTF8StringEncoding];
        [ret appendData:keyNameData];
        
        
        
        uint32_t valueLength = getValueLength(value);
        NSData* valueLengthData = Uint32ToLittleEndianData(valueLength);
        [ret appendData:valueLengthData];
        
        
        
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
        slog(@"Not enough data to read Entry header.");
        return nil;
    }
    
    
    uint8_t versionMajor = buffer[1];
    
    if(versionMajor != 1) {
        slog(@"Variant Dictionary major version != 1");
        return nil;
    }
    
    EntryHeader* header = (EntryHeader*)&buffer[2];

    while(header->type != 0) {
        size_t keyLength = littleEndian4BytesToUInt32(header->keyLength);

        if(header->keyData + keyLength > eof) {
            slog(@"Not enough data to read Entry header Key.");
            return nil;
        }
        
        NSString* key = getKey(header->keyData, keyLength);
        
        
        
        if(!key) {
            slog(@"Could not get key from Variant Dictionary.");
            return nil;
        }
        
        uint8_t *value = ((uint8_t*)header) + (SIZE_OF_ENTRY_HEADER + keyLength);
        size_t valueLength = littleEndian4BytesToUInt32(value);
        
        if(value + valueLength > eof) {
            slog(@"Not enough data to read Entry header value.");
            return nil;
        }
        
        NSObject* theObj = getObject(header->type, value + 4, valueLength);
        VariantObject *obj = [[VariantObject alloc] initWithType:header->type theObject:theObj];
        
        if(obj) {
            [ret setObject:obj forKey:key];
        }
        
        uint8_t *next = value + (valueLength + 4);
        
        if(next + 1 > eof) {
            slog(@"Not enough data to read next Entry header Key.");
            return nil;
        }
        
        header = (EntryHeader*)next;
    }
    
    return ret;
}

static NSData* getValueAsData(VariantObject* value) {
    switch (value.type) {
        case kVariantTypeUint32: 
            return Uint32ToLittleEndianData(((NSNumber*)value.theObject).unsignedIntValue);
            break;
        case kVariantTypeUint64: 
            return Uint64ToLittleEndianData(((NSNumber*)value.theObject).unsignedLongLongValue);
            break;
        case kVariantTypeInt32: 
            return Int32ToLittleEndianData(((NSNumber*)value.theObject).intValue);
            break;
        case kVariantTypeInt64: 
            return Int64ToLittleEndianData(((NSNumber*)value.theObject).longLongValue);
            break;
        case kVariantTypeBool: 
            {
                uint8_t boolBytes[] = { ((NSNumber*)value.theObject).boolValue };
                return [NSData dataWithBytes:boolBytes length:1]; 
            }
            break;
        case kVariantTypeString: 
            return [((NSString*)value.theObject) dataUsingEncoding:NSUTF8StringEncoding];
            break;
        case kVariantTypeByteArray: 
            return ((NSData*)value.theObject);
            break;
        default:
            slog(@"WARN: Unknown Variant Dictionary Value Type = %d. returning as Data", value.type);
            return [NSData data];
            break;
    }
}

static NSObject* getObject(uint8_t type, void* data, size_t length) {
    switch (type) {
        case kVariantTypeUint32: 
            return [NSNumber numberWithUnsignedInt:littleEndian4BytesToUInt32(data)];
            break;
        case kVariantTypeUint64: 
            return [NSNumber numberWithUnsignedLongLong:littleEndian8BytesToUInt64(data)];
            break;
        case kVariantTypeInt32: 
            return [NSNumber numberWithInt:(int32_t)littleEndian4BytesToUInt32(data)];
            break;
        case kVariantTypeInt64: 
            return [NSNumber numberWithLongLong:(int64_t)littleEndian8BytesToUInt64(data)];
            break;
        case kVariantTypeBool: 
            return @(*((uint8_t*)data) == 1);
            break;
        case kVariantTypeString: 
            return getKey(data, length);
            break;
        case kVariantTypeByteArray: 
            return [NSData dataWithBytes:data length:length];
            break;
        default:
            slog(@"WARN: Unknown Variant Dictionary Value Type = %d. returning as Data", type);
            return [NSData dataWithBytes:data length:length];
            break;
    }
}

static uint32_t getValueLength(VariantObject* value) {
    switch (value.type) {
        case kVariantTypeInt32:
        case kVariantTypeUint32: 
            return 4;
            break;
        case kVariantTypeInt64:
        case kVariantTypeUint64: 
            return 8;
            break;
        case kVariantTypeBool: 
            return 1;
            break;
        case kVariantTypeString: 
            return (uint32_t)((NSString*)value.theObject).length;
            break;
        case kVariantTypeByteArray: 
            return (uint32_t)((NSData*)value.theObject).length;
            break;
        default:
            slog(@"WARN: Unknown Variant Dictionary Value Type = %d. returning 0", value.type);
            return 0;
            break;
    }
}

static NSString* getKey(void* data, size_t length) {
    return [[NSString alloc] initWithBytes:data length:length encoding:NSUTF8StringEncoding];
}

@end
