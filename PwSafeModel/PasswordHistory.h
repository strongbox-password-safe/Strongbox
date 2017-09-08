//
//  PasswordHistory.h
//  StrongBox
//
//  Created by Mark on 28/05/2017.
//  Copyright © 2017 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "PasswordHistoryEntry.h"

@interface PasswordHistory : NSObject

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

typedef struct _Header {
    char enabled;
    char maximumSize[2];
    char currentSize[2];
} Header;
#define SIZE_OF_HEADER       5

typedef struct _EntryHeader {
    char hexEpoch[8];
    char passwordLength[4];
} EntryHeader;
#define SIZE_OF_ENTRY_HEADER 12

@property (nonatomic) BOOL enabled;
@property (nonatomic, assign) NSUInteger maximumSize;
@property (nonatomic, retain, nonnull) NSMutableArray<PasswordHistoryEntry *> *entries;

- (instancetype _Nullable )initWithData:(NSData *_Nonnull)data;

@property (NS_NONATOMIC_IOSONLY, getter = getAsData, readonly, copy) NSData * _Nonnull asData;

@end
