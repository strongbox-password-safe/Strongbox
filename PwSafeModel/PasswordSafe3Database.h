//
//  OpenSafe.h
//  StrongBox
//
//  Created by Mark McGuill on 05/06/2014.
//  Copyright (c) 2014 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SafeTools.h"
#import "Record.h"

#define MAX_SAFE_SIZE (1024 * 1024)

@interface PasswordSafe3Database : NSObject

@property (readonly) NSDate *lastUpdateTime;
@property (readonly) NSString *lastUpdateUser;
@property (readonly) NSString *lastUpdateHost;
@property (readonly) NSString *lastUpdateApp;

@property (nonatomic, retain) NSString *masterPassword;

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initNewWithoutPassword;
- (instancetype)initNewWithPassword:(NSString *)masterPassword NS_DESIGNATED_INITIALIZER;
- (instancetype)initExistingWithData:(NSString *)password data:(NSData *)safeData error:(NSError **)ppError NS_DESIGNATED_INITIALIZER;

- (NSArray<Group*> *)getImmediateSubgroupsForParent:(Group *)parent
                       withFilter:(NSString *)filter
                       deepSearch:(BOOL)deepSearch;

- (NSArray<Record*> *)getRecordsForGroup:(Group *)parent
                     withFilter:(NSString *)filter
                     deepSearch:(BOOL)deepSearch;

@property (NS_NONATOMIC_IOSONLY, getter = getAllRecords, readonly, copy) NSArray<Record*> *allRecords;

- (Record*)addRecord:(Record *)newRecord;
- (Group *)createGroupWithTitle:(Group *)parent title:(NSString *)title validateOnly:(BOOL)validateOnly;

- (void)deleteRecord:(Record *)record;
- (void)deleteGroup:(Group *)group;

- (NSData*)getAsData:(NSError**)error;

+ (BOOL)isAValidSafe:(NSData *)candidate;

// Move

- (BOOL)moveGroup:(Group *)src destination:(Group *)destination validateOnly:(BOOL)validateOnly;
- (BOOL)moveRecord:(Record *)src destination:(Group *)destination validateOnly:(BOOL)validateOnly;

- (Record*)getRecordByUuid:(NSString*)uuid;
- (Group*)getGroupByEscapedPathString:(NSString*)escapedPathString;

@end
