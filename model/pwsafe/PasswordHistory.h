//
//  PasswordHistory.h
//  StrongBox
//
//  Created by Mark on 28/05/2017.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "PasswordHistoryEntry.h"

NS_ASSUME_NONNULL_BEGIN

@interface PasswordHistory : NSObject

//    [12] Password History is an optional record. If it exists, it stores the

















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

- (instancetype)clone;

@end

NS_ASSUME_NONNULL_END
