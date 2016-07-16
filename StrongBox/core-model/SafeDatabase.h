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

@interface SafeDatabase : NSObject

@property (readonly) NSDate   *lastUpdateTime;
@property (readonly) NSString *lastUpdateUser;
@property (readonly) NSString *lastUpdateHost;
@property (readonly) NSString *lastUpdateApp;

@property NSString *masterPassword;

-(SafeDatabase*)initNewWithPassword:(NSString*)masterPassword;
-(SafeDatabase*)initExistingWithData:(NSString*)password data:(NSData*)safeData error:(NSError**)ppError;

- (NSArray*)getSubgroupsForGroup:(Group*)parent
                      withFilter:(NSString*)filter
                      deepSearch:(BOOL)deepSearch;

- (NSArray*)getRecordsForGroup:(Group*)parent
                    withFilter:(NSString*)filter
                    deepSearch:(BOOL)deepSearch;

- (NSArray*)getAllRecords;

-(void)addRecord:(Record*)newRecord;
-(Group*)addSubgroupWithUIString:(Group*)parent title:(NSString*)title;

-(void)deleteRecord:(Record*)record;
-(void)deleteGroup:(Group*)group;

-(NSData*) getAsData;

//

+(BOOL)isAValidSafe:(NSData*)candidate;

// Move

-(BOOL)moveGroup:(Group*)src destination:(Group*)destination validate:(BOOL)validate;
-(BOOL)moveRecord:(Record*)src destination:(Group*)destination validate:(BOOL)validate;

@end
