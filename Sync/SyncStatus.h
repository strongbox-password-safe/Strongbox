//
//  SyncOperationInfo.h
//  Strongbox
//
//  Created by Strongbox on 20/07/2020.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SyncStatusLogEntry.h"

NS_ASSUME_NONNULL_BEGIN

@interface SyncStatus : NSObject

@property (readonly) NSString* databaseId;
@property (readonly) SyncOperationState state;
@property (readonly, nullable) NSError* error;
@property (readonly, nullable) NSString* message;

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithDatabaseId:(NSString*)databaseId NS_DESIGNATED_INITIALIZER;


- (void)addLogMessage:(NSString*)message syncId:(NSUUID *)syncId;
- (void)updateStatus:(SyncOperationState)state syncId:(NSUUID *)syncId error:(NSError*_Nullable)error;
- (void)updateStatus:(SyncOperationState)state syncId:(NSUUID *)syncId message:(NSString*)message;

@property (readonly) NSArray<SyncStatusLogEntry*> *changeLog;

@end

NS_ASSUME_NONNULL_END
