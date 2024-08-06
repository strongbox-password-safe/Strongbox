//
//  KdbSerialization.m
//  Strongbox
//
//  Created by Mark on 08/11/2018.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import "KdbSerialization.h"
#import "KdbxSerializationCommon.h"
#import "Utils.h"
#import "AesCipher.h"
#import "TwoFishCipher.h"
#import "KdbGroup.h"
#import "KdbEntry.h"
#import "KdbSerializationData.h"
#import "KeePassConstants.h"
#import <CommonCrypto/CommonDigest.h>
#import "NSString+Extensions.h"
#import "NSData+Extensions.h"
#import "StrongboxErrorCodes.h"

typedef struct _KdbHeader {
    uint8_t signature1[4];
    uint8_t signature2[4];
    uint8_t flags[4];
    uint8_t version[4];
    uint8_t masterSeed[16];
    uint8_t encryptionIv[16];
    uint8_t numberOfGroups[4];
    uint8_t numberOfEntries[4];
    uint8_t contentsHash[32];
    uint8_t transformSeed[32];
    uint8_t transformRounds[4];
} KdbHeader;
#define SIZE_OF_KDB_HEADER 124

typedef struct _FieldHeader {
    uint8_t type[2];
    uint8_t length[4];
    uint8_t data[];
} FieldHeader;
#define SIZE_OF_FIELD_HEADER 6

static const int kBlockSize = 16;
static const int kKdbMasterSeedLength = 16;
static const uint32_t kSignature1 = 0x9AA2D903;
static const uint32_t kSignature2 = 0xB54BFB65;

static const BOOL kLogVerbose = NO;

@implementation KdbSerialization

+ (BOOL)isAValidSafe:(nullable NSData *)candidate error:(NSError**)error {
    if(candidate.length < SIZE_OF_KDB_HEADER) {
        return NO;
    }
    
    KdbHeader *header = (KdbHeader*)candidate.bytes;

    if (header->signature1[0] != 0x03 ||
        header->signature1[1] != 0xD9 ||
        header->signature1[2] != 0xA2 ||
        header->signature1[3] != 0x9A) {
        
        if(error) {
            *error = [Utils createNSError:@"No Keepass magic" errorCode:-1];
        }
        return NO;
    }
    
    if (header->signature2[0] != 0x65 ||
        header->signature2[1] != 0xFB ||
        header->signature2[2] != 0x4B ||
        header->signature2[3] != 0xB5) {

        if(error) {
            *error = [Utils createNSError:@"No Keepass magic (2)" errorCode:-1];
        }

        
        return NO;
    }

    return YES;
}

static NSData *getComposite(NSString * _Nonnull password, NSData * _Nullable keyFileDigest) {
    if(password.length && !keyFileDigest) {
        return password.sha256Data;
    }
    else if(keyFileDigest && !password.length) {
        return keyFileDigest;
    }
    else {
        NSData* hashedPassword = password.sha256Data;
        
        NSMutableData *compositeKey = [NSMutableData dataWithLength:CC_SHA256_DIGEST_LENGTH ];
        CC_SHA256_CTX context;
        CC_SHA256_Init(&context);
        
        if(hashedPassword) {
            CC_SHA256_Update(&context, hashedPassword.bytes, (CC_LONG)hashedPassword.length);
        }
        
        if(keyFileDigest) {
            CC_SHA256_Update(&context, keyFileDigest.bytes, (CC_LONG)keyFileDigest.length);
        }
        
        CC_SHA256_Final(compositeKey.mutableBytes, &context);
        return compositeKey;
    }
}

+ (KdbSerializationData*)deserialize:(NSData*)data password:(NSString*)password keyFileDigest:(NSData *)keyFileDigest ppError:(NSError**)error {
    if(data.length < SIZE_OF_KDB_HEADER) {
        slog(@"Not a valid KDB file. Not long enough.");
        if(error) {
            *error = [Utils createNSError:@"Not a valid KDB file. Not long enough" errorCode:-1];
        }
        return nil;
    }
    
    KdbHeader *header = (KdbHeader*)data.bytes;

    uint32_t flags = littleEndian4BytesToUInt32(header->flags);
    uint32_t version = littleEndian4BytesToUInt32(header->version);
    NSData* masterSeed = [NSData dataWithBytes:header->masterSeed length:kKdbMasterSeedLength];
    NSData* encryptionIv = [NSData dataWithBytes:header->encryptionIv length:16];
    uint32_t cGroups = littleEndian4BytesToUInt32(header->numberOfGroups);
    uint32_t cEntries = littleEndian4BytesToUInt32(header->numberOfEntries);
    NSData* contentsSha256 = [NSData dataWithBytes:header->contentsHash length:32];
    NSData* transformSeed = [NSData dataWithBytes:header->transformSeed length:32];
    uint32_t transformRounds = littleEndian4BytesToUInt32(header->transformRounds);

    if(kLogVerbose) {
        slog(@"DESERIALIZE");
        slog(@"flags = %0.8X", flags);
        slog(@"version = %0.8X", version);
        slog(@"masterSeed = %@", [masterSeed base64EncodedStringWithOptions:kNilOptions]);
        slog(@"encryptionIv = %@", [encryptionIv base64EncodedStringWithOptions:kNilOptions]);
        slog(@"cGroups = %d", cGroups);
        slog(@"cEntries = %d", cEntries);
        slog(@"contentsSha256 = %@", [contentsSha256 base64EncodedStringWithOptions:kNilOptions]);
        slog(@"transformSeed = %@", [transformSeed base64EncodedStringWithOptions:kNilOptions]);
        slog(@"transformRounds = %d", transformRounds);
    }
    
    if(cGroups == 0) {
        slog(@"Not a valid KDB file. Zero Groups.");
        if(error) {
            *error = [Utils createNSError:@"Not a valid KDB file. Zero Groups." errorCode:-2];
        }
        return nil;
    }
    
    
    
    
    size_t length = data.length - SIZE_OF_KDB_HEADER;
    
    if((length % kBlockSize) != 0) {
        slog(@"Database Length is not a multiple of the blocksize. This file is likely corrupt.");
        if(error) {
            *error = [Utils createNSError:@"Database Length is not a multiple of the blocksize. This file is likely corrupt." errorCode:-4];
        }
        return nil;
    }
    
    NSData* compositeKey = getComposite(password, keyFileDigest);
    
    
    
    
    NSData *transformKey = getAesTransformKey(compositeKey, transformSeed, transformRounds);
    NSData *masterKey = getMasterKey(masterSeed, transformKey);
    NSData *ct = [data subdataWithRange:NSMakeRange(SIZE_OF_KDB_HEADER, length)];
    
    id<Cipher> cipher = getCipher(flags);
    if(cipher == nil) {
        slog(@"Unknown Cipher. Cannot open this file.");
        if(error) {
            *error = [Utils createNSError:@"Unknown Cipher. Cannot open this file." errorCode:-3];
        }
        return nil;
    }
    
    NSData *pt = [cipher decrypt:ct iv:encryptionIv key:masterKey];

    

    if(![pt.sha256 isEqualToData:contentsSha256]) {
        slog(@"Actual Database Contents Hash does not match expected. This file is corrupt or the password is incorect.");
        if(error) {
            *error = [Utils createNSError:@"Incorrect Passphrase/Key File (Composite Key) or Corrupt File." errorCode:StrongboxErrorCodes.incorrectCredentials];
        }
        return nil;
    }
    
    uint8_t *position = (uint8_t*)pt.bytes;
    uint8_t *eof = (uint8_t*)pt.bytes + pt.length;
    
    KdbSerializationData *ret = [[KdbSerializationData alloc] init];
    
    for(int i=0;i<cGroups;i++) {
        KdbGroup* group = readGroup(&position, eof);
        if(!group) {
            slog(@"Could not read group.");
            if(error) {
                *error = [Utils createNSError:@"Could not read group." errorCode:-6];
            }
            return nil;
        }
        [ret.groups addObject:group];
    }

    for(int i=0;i<cEntries;i++) {
        KdbEntry* entry = readEntry(&position, eof);
        if(!entry) {
            slog(@"Could not read entry.");
            if(error) {
                *error = [Utils createNSError:@"Could not read entry." errorCode:-7];
            }
            return nil;
        }
        
        if(entry.isMetaEntry) {
            [ret.metaEntries addObject:entry];
        }
        else {
            [ret.entries addObject:entry];
        }
    }
    
    ret.version = version;
    ret.flags = flags;
    ret.transformRounds = transformRounds;
    
    return ret;
}

+ (NSData*)serialize:(KdbSerializationData*)serializationData password:(NSString*)password keyFileDigest:(NSData *)keyFileDigest ppError:(NSError**)error {
    if(kLogVerbose) {
        slog(@"SERIALIZE: %@", serializationData);
    }
    
    if(serializationData.groups.count == 0) {
        slog(@"Not a valid KDB file. Zero Groups.");
        if(error) {
            *error = [Utils createNSError:@"Not a valid database. Zero Groups." errorCode:-1];
        }
        return nil;
    }
    
    NSMutableData *pt = [NSMutableData data];
    for (KdbGroup* group in serializationData.groups) {
        [pt appendData:writeGroup(group)];
    }
    
    for (KdbEntry* entry in serializationData.entries) {
        [pt appendData:writeEntry(entry)];
    }
    
    for (KdbEntry* entry in serializationData.metaEntries) {
        [pt appendData:writeEntry(entry)];
    }
    
    NSData* contentsHash = pt.sha256;
    
    
    NSData *compositeKey = getComposite(password, keyFileDigest);
    
    
    
    NSData* transformSeed = getRandomData(kDefaultTransformSeedLength);
    NSData* transformKey = getAesTransformKey(compositeKey, transformSeed, serializationData.transformRounds);
    NSData* masterSeed = getRandomData(kKdbMasterSeedLength);
    NSData *masterKey = getMasterKey(masterSeed, transformKey);
    
    id<Cipher> cipher = getCipher(serializationData.flags);
    
    NSData* encryptionIv = [cipher generateIv];

    NSData *ct = [cipher encrypt:pt iv:encryptionIv key:masterKey];

    

    if(kLogVerbose) {
        slog(@"SERIALIZE");
        slog(@"flags = %0.8X", serializationData.flags);
        slog(@"version = %0.8X", serializationData.version);
        slog(@"masterSeed = %@", [masterSeed base64EncodedStringWithOptions:kNilOptions]);
        slog(@"encryptionIv = %@", [encryptionIv base64EncodedStringWithOptions:kNilOptions]);
        slog(@"cGroups = %lu", (unsigned long)serializationData.groups.count);
        slog(@"cEntries = %lu", (unsigned long)serializationData.entries.count + (unsigned long)serializationData.metaEntries.count);
        slog(@"contentsSha256 = %@", [contentsHash base64EncodedStringWithOptions:kNilOptions]);
        slog(@"transformSeed = %@", [transformSeed base64EncodedStringWithOptions:kNilOptions]);
        slog(@"transformRounds = %d", serializationData.transformRounds);
    }
    
    KdbHeader header;
    
    [Uint32ToLittleEndianData(kSignature1) getBytes:header.signature1 length:4];
    [Uint32ToLittleEndianData(kSignature2) getBytes:header.signature2 length:4];
    [Uint16ToLittleEndianData(serializationData.flags) getBytes:header.flags length:4];
    [Uint32ToLittleEndianData(serializationData.version) getBytes:header.version length:4];
    [masterSeed getBytes:header.masterSeed length:kKdbMasterSeedLength];
    [encryptionIv getBytes:header.encryptionIv  length:16];
    [Uint32ToLittleEndianData((uint32_t)serializationData.groups.count) getBytes:header.numberOfGroups length:4];
    [Uint32ToLittleEndianData((uint32_t)(serializationData.entries.count + serializationData.metaEntries.count)) getBytes:header.numberOfEntries length:4];
    [contentsHash getBytes:header.contentsHash length:contentsHash.length];
    [transformSeed getBytes:header.transformSeed length:kDefaultTransformSeedLength];
    [Uint32ToLittleEndianData(serializationData.transformRounds) getBytes:header.transformRounds length:4];
    
    NSMutableData* ret = [NSMutableData dataWithBytes:&header length:SIZE_OF_KDB_HEADER];
    
    [ret appendData:ct];
    
    return ret;
}

static id<Cipher> getCipher(uint32_t flags) {
    if ((flags & kFlagsAes) == kFlagsAes) {
        return [[AesCipher alloc] init];
    }
    else if ((flags & kFlagsTwoFish) == kFlagsTwoFish) {
        return [[TwoFishCipher alloc] init];
    }
    else {
        return nil;
    }
}


NSData* writeField(uint16_t type, NSData* data) {
    NSMutableData *ret = [NSMutableData data];
    
    [ret appendData:Uint16ToLittleEndianData(type)];
    [ret appendData:Uint32ToLittleEndianData((uint32_t)data.length)];
    [ret appendData:data];
    
    return ret;
}

NSData* writeGroup(KdbGroup* group) {
    NSMutableData *ret = [NSMutableData data];

    [ret appendData:writeField(0x0001, Uint32ToLittleEndianData(group.groupId))];
    [ret appendData:writeField(0x0002, stringtoKeePassData(group.name))];
    if (group.creation) [ret appendData:writeField(0x0003, dateToKeePass1Data(group.creation))];
    if (group.modification) [ret appendData:writeField(0x0004, dateToKeePass1Data(group.modification))];
    if (group.lastAccess) [ret appendData:writeField(0x0005, dateToKeePass1Data(group.lastAccess))];
    if (group.expiry) [ret appendData:writeField(0x0006, dateToKeePass1Data(group.expiry))];
    if (group.imageId != nil) [ret appendData:writeField(0x0007, Uint32ToLittleEndianData(group.imageId.intValue))];
    [ret appendData:writeField(0x0008, Uint16ToLittleEndianData(group.level))];
    [ret appendData:writeField(0x0009, Uint32ToLittleEndianData(group.flags))];
    [ret appendData:writeField(0xFFFF, [NSData data])];
                               
    return ret;
}

NSData* writeEntry(KdbEntry* entry) {
    NSMutableData *ret = [NSMutableData data];

    uuid_t uuid;
    [entry.uuid getUUIDBytes:(uint8_t*)&uuid];
    
    [ret appendData:writeField(0x0001, [NSData dataWithBytes:uuid length:sizeof(uuid_t)])];
    [ret appendData:writeField(0x0002, Uint32ToLittleEndianData(entry.groupId))];
    
    if (entry.imageId != nil) [ret appendData:writeField(0x0003, Uint32ToLittleEndianData(entry.imageId.intValue))];
    
    [ret appendData:writeField(0x0004, stringtoKeePassData(entry.title))];
    [ret appendData:writeField(0x0005, stringtoKeePassData(entry.url))];
    [ret appendData:writeField(0x0006, stringtoKeePassData(entry.username))];
    [ret appendData:writeField(0x0007, stringtoKeePassData(entry.password))];
    [ret appendData:writeField(0x0008, stringtoKeePassData(entry.notes))];
    if (entry.creation) [ret appendData:writeField(0x0009, dateToKeePass1Data(entry.creation))];
    if (entry.modified) [ret appendData:writeField(0x000A, dateToKeePass1Data(entry.modified))];
    if (entry.accessed) [ret appendData:writeField(0x000B, dateToKeePass1Data(entry.accessed))];
    if (entry.expired) [ret appendData:writeField(0x000C, dateToKeePass1Data(entry.expired))];
    
    if(entry.binaryFileName) {
        [ret appendData:writeField(0x000D,stringtoKeePassData(entry.binaryFileName))];
        [ret appendData:writeField(0x000E, entry.binaryData)];
    }

    [ret appendData:writeField(0xFFFF, [NSData data])];
                                   
    return ret;
}

static NSData* stringtoKeePassData(NSString* str) {
    NSString *foo = str ? str : @"";
    
    const char *utf8 = foo.UTF8String;
    size_t len = strlen(utf8);
    
    return [NSData dataWithBytes:utf8 length:len + 1]; 
}

static NSString* keePassDataToString(uint8_t *data) {
    return [[NSString alloc] initWithCString:(char*)data encoding:NSUTF8StringEncoding];
}



typedef void (*updateItemWithFieldFn)(uint16_t type, uint32_t length, uint8_t *data, NSObject* item);

KdbGroup* readGroup(uint8_t** position, uint8_t* eof) {
    KdbGroup *group = [[KdbGroup alloc] init];
    return (KdbGroup*)readItem(position, eof, group, updateGroupWithField);
}

KdbEntry* readEntry(uint8_t** position, uint8_t* eof) {
    KdbEntry* entry = [[KdbEntry alloc] init];
    return (KdbEntry*)readItem(position, eof, entry, updateEntryWithField);
}

NSObject* readItem(uint8_t** position, uint8_t* eof, NSObject* item, updateItemWithFieldFn updateWithFieldFn) {
    uint8_t *pos = *position;
   
    while(YES) {
        if((pos + SIZE_OF_FIELD_HEADER) > eof) {
            return nil;
        }
        
        FieldHeader *fieldHeader = (FieldHeader*)pos;
        uint16_t type = littleEndian2BytesToUInt16(fieldHeader->type);
        uint32_t length = littleEndian4BytesToUInt32(fieldHeader->length);

        if(type == 0xFFFF) {
            break;
        }
        
        if((pos + SIZE_OF_FIELD_HEADER + length) > eof) {
            return nil;
        }
        
        updateWithFieldFn(type, length, fieldHeader->data, item);
 
        pos += SIZE_OF_FIELD_HEADER + length;
    }
    
    pos += SIZE_OF_FIELD_HEADER;
    *position = pos;
    
    return item;
}

void updateGroupWithField(uint16_t type, uint32_t length, uint8_t *data, KdbGroup* group) {
    switch (type) {
        case 0x0000:









            break;
        case 0x0001:
            group.groupId = littleEndian4BytesToUInt32(data);
            break;
        case 0x0002:
            group.name = keePassDataToString(data);
            break;
        case 0x0003:
            group.creation = keePass1TimeToDate(data);
            break;
        case 0x0004:
            group.modification = keePass1TimeToDate(data);
            break;
        case 0x0005:
            group.lastAccess = keePass1TimeToDate(data);
            break;
        case 0x0006:
            group.expiry = keePass1TimeToDate(data);
            break;
        case 0x0007:
            group.imageId = @(littleEndian4BytesToUInt32(data));
            break;
        case 0x0008:
            group.level = littleEndian2BytesToUInt16(data);
            break;
        case 0x0009:
            group.flags = littleEndian4BytesToUInt32(data);
            break;
        default:
            break;
    }
}

void updateEntryWithField(uint16_t type, uint32_t length, uint8_t *data, KdbEntry* entry) {
    switch (type) {
        case 0x0000:
            
            break;
        case 0x0001:
            entry.uuid = [[NSUUID alloc] initWithUUIDBytes:data];
            break;
        case 0x0002:
            entry.groupId = littleEndian4BytesToUInt32(data);
            break;
        case 0x0003:
            entry.imageId = @(littleEndian4BytesToUInt32(data));
            break;
        case 0x0004:
            entry.title = keePassDataToString(data);
            break;
        case 0x0005:
            entry.url = keePassDataToString(data);
            break;
        case 0x0006:
            entry.username = keePassDataToString(data);
            break;
        case 0x0007:
            entry.password = keePassDataToString(data);
            break;
        case 0x0008:
            entry.notes = keePassDataToString(data);
            break;
        case 0x0009:
            entry.creation = keePass1TimeToDate(data);
            break;
        case 0x000A:
            entry.modified = keePass1TimeToDate(data);
            break;
        case 0x000B:
            entry.accessed = keePass1TimeToDate(data);
            break;
        case 0x000C:
            entry.expired = keePass1TimeToDate(data);
            break;
        case 0x000D:
            entry.binaryFileName = keePassDataToString(data);
            break;
        case 0x000E:
            entry.binaryData = [NSData dataWithBytes:data length:length];
            break;
        default:
            break;
    }
}

NSData* dateToKeePass1Data(NSDate* date)
{
    NSCalendar* calender = [[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian];
    uint32_t flags = NSCalendarUnitYear | NSCalendarUnitMonth |  NSCalendarUnitDay | NSCalendarUnitHour | NSCalendarUnitMinute | NSCalendarUnitSecond;
    NSDateComponents* c = [calender components:flags fromDate:date];
    
    NSMutableData *ret = [NSMutableData dataWithLength:5];
    
    ((uint8_t*)ret.mutableBytes)[0] = (uint8_t)((c.year >> 6) & 0x0000003F);
    ((uint8_t*)ret.mutableBytes)[1] = (uint8_t)(((c.year & 0x0000003F) << 2) | ((c.month >> 2) & 0x00000003));
    ((uint8_t*)ret.mutableBytes)[2] = (uint8_t)(((c.month & 0x00000003) << 6) | ((c.day & 0x0000001F) << 1) | ((c.hour >> 4) & 0x00000001));
    ((uint8_t*)ret.mutableBytes)[3] = (uint8_t)(((c.hour & 0x0000000F) << 4) | ((c.minute >> 2) & 0x0000000F));
    ((uint8_t*)ret.mutableBytes)[4] = (uint8_t)(((c.minute & 0x00000003) << 6) | (c.second & 0x0000003F));

    return ret;
}

NSDate* keePass1TimeToDate(const uint8_t *keePassTime)
{
    uint32_t b1 = (uint32_t)keePassTime[0];
    uint32_t b2 = (uint32_t)keePassTime[1];
    uint32_t b3 = (uint32_t)keePassTime[2];
    uint32_t b4 = (uint32_t)keePassTime[3];
    uint32_t b5 = (uint32_t)keePassTime[4];
    
    NSDateComponents *components = [[NSDateComponents alloc] init];
    
    [components setYear:(b1 << 6) | (b2 >> 2)];
    [components setMonth:((b2 & 0x00000003) << 2) | (b3 >> 6)];
    [components setDay:(b3 >> 1) & 0x0000001F];
    [components setHour:((b3 & 0x00000001) << 4) | (b4 >> 4)];
    [components setMinute:((b4 & 0x0000000F) << 2) | (b5 >> 6)];
    [components setSecond:b5 & 0x0000003F];
    
    NSCalendar* calender = [[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian];
    
    return [calender dateFromComponents:components];
}

@end
