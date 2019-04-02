//
//  PasswordHistory.m
//  StrongBox
//
//  Created by Mark on 28/05/2017.
//  Copyright © 2017 Mark McGuill. All rights reserved.
//
//    [12] Password History is an optional record. If it exists, it stores the
//    creation times and values of the last few passwords used in the current
//    entry, in the following format:
//    "fmmnnTLPTLP...TLP"
//where:
//    f  = {0,1} if password history is on/off
//        mm = 2 hexadecimal digits max size of history list (i.e. max = 255)
//        nn = 2 hexadecimal digits current size of history list
//        T  = Time password was set (time_t written out in %08x)
//        L  = 4 hexadecimal digit password length (in TCHAR)
//        P  = Password
//        No history being kept for a record can be represented either by the lack of
//            the PWH field (preferred), or by a header of _T("00000"):
//            flag = 0, max = 00, num = 00
//            Note that 0aabb, where bb <= aa, is possible if password history was enabled
//                in the past and has then been disabled but the history hasn't been cleared.
//

// PWHIST => 10603592b151b0003abc592b153d0003def592b154f0003ghi =>
// bytes[<31303630 33353932 62313531 62303030 33616263 35393262 31353364 30303033 64656635 39326231 35346630 30303367 6869>]

#import "PasswordHistory.h"

@implementation PasswordHistory

- (instancetype)init {
    if (self = [super init]) {
        _enabled = NO;
        _maximumSize = 3;
        _entries = [[NSMutableArray alloc] init];

        return self;
    }
    else {
        return nil;
    }
}

- (instancetype)initWithData:(NSData *)data {
    if (self = [self init]) {
        if (data.length < SIZE_OF_HEADER) {
            NSLog(@"Invalid data for pwhist. Needs to be minimum 5 bytes for header. %@", data);
            return nil;
        }

        Header header;
        [data getBytes:&header length:5];

        //NSLog(@"PWHIST Header: %@", header);

        _enabled = (header.enabled == '1');
        
        _maximumSize = [self getIntegerFromHexCharArray:header.maximumSize length:2];
        NSUInteger numberOfEntries = [self getIntegerFromHexCharArray:header.currentSize length:2];
        
        int currentEntryStartOffset = 5;

        for (int i = 0; i < numberOfEntries; i++) {
            if (data.length < (currentEntryStartOffset + SIZE_OF_ENTRY_HEADER)) {
                NSLog(@"Invalid size for pwhist. %@", data);
                return nil;
            }

            EntryHeader entryHeader;
            [data getBytes:&entryHeader range:NSMakeRange(currentEntryStartOffset, SIZE_OF_ENTRY_HEADER)];

            unsigned long ts = [self getIntegerFromHexCharArray:entryHeader.hexEpoch length:8];

            NSDate *timestamp = [NSDate dateWithTimeIntervalSince1970:ts];

            NSUInteger passwordLength = [self getIntegerFromHexCharArray:entryHeader.passwordLength length:4];
            if (data.length < (currentEntryStartOffset + SIZE_OF_ENTRY_HEADER + passwordLength)) {
                NSLog(@"Invalid current size for pwhist. %@", data);
                return nil;
            }

            NSString *password = @"";
            if(passwordLength > 0) {
                char pw[passwordLength];
                
                [data getBytes:pw range:NSMakeRange(currentEntryStartOffset + SIZE_OF_ENTRY_HEADER, passwordLength)];

                password = [self getStringFromCharArray:pw length:passwordLength];
            }
            
            PasswordHistoryEntry *entry = [[PasswordHistoryEntry alloc] initWithTimestamp:timestamp password:password];
            [self.entries addObject:entry];

            currentEntryStartOffset += SIZE_OF_ENTRY_HEADER + passwordLength;
        }

        return self;
    }
    else {
        return nil;
    }
}

- (NSData *)getAsData {
    int entriesSize = 0;

    for (int i = 0; i < (self.entries).count; i++) {
        PasswordHistoryEntry *entry = (self.entries)[i];
        entriesSize += SIZE_OF_ENTRY_HEADER;
        entriesSize += strlen((entry.password).UTF8String);
    }

    int bufSize = SIZE_OF_HEADER + entriesSize;
    char buf[bufSize];

    buf[0] = self.enabled ? '1' : '0';
    sprintf(&buf[1], "%02lx", (unsigned long)self.maximumSize);
    sprintf(&buf[3], "%02lx", (unsigned long)[self.entries count]);

    char *entryStart = &buf[5];

    for (int i = 0; i < (self.entries).count; i++) {
        PasswordHistoryEntry *entry = (self.entries)[i];

        sprintf(entryStart, "%08lx", (unsigned long)[entry.timestamp timeIntervalSince1970]);

        const char *password = (entry.password).UTF8String;
        sprintf(entryStart + 8, "%04lx", strlen(password));
        sprintf(entryStart + 12, "%s", password);

        entryStart += 8 + 4 + strlen(password);
    }

    return [[NSData alloc] initWithBytes:buf length:bufSize];
}

- (NSString*)getStringFromCharArray:(char *)array length:(NSUInteger)length {
    char foo[length + 1];
    
    memcpy(foo, array, length);
    foo[length] = 0;
    
    return @(foo);
}

- (NSUInteger)getIntegerFromHexCharArray:(char *)array length:(NSUInteger)length {
    NSString* ret = [self getStringFromCharArray:array length:length];

    if(!ret.length) {
        return 0;
    }
    
    const char* c = ret.UTF8String;

    if(c == nil) {
        return 0;
    }
    
    return strtoul(c, NULL, 16);
}

@end
