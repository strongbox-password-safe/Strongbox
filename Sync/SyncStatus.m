//
//  SyncOperationInfo.m
//  Strongbox
//
//  Created by Strongbox on 20/07/2020.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import "SyncStatus.h"
#import "ConcurrentMutableArray.h"
#import "ConcurrentCircularBuffer.h"

@interface SyncStatus ()

@property ConcurrentCircularBuffer* log;

@end

const NSUInteger kLogCapacity = 128;

@implementation SyncStatus

- (instancetype)initWithDatabaseId:(NSString *)databaseId {
    self = [super init];
    
    if (self) {
        _databaseId = databaseId;
        _state = kSyncOperationStateInitial;
        self.log = [[ConcurrentCircularBuffer alloc] initWithCapacity:kLogCapacity];
    }
    
    return self;
}

- (void)addLogMessage:(NSString *)message syncId:(NSUUID *)syncId {
    SyncStatusLogEntry* entry = [SyncStatusLogEntry logWithState:self.state syncId:syncId message:message error:nil];

    [self.log addObject:entry];
}

- (void)updateStatus:(SyncOperationState)state syncId:(NSUUID *)syncId error:(NSError *)error {
    [self updateStatus:state syncId:syncId message:@"" error:error];
}

- (void)updateStatus:(SyncOperationState)state syncId:(NSUUID *)syncId message:(NSString *)message {
    [self updateStatus:state syncId:syncId message:message error:nil];
}

- (void)updateStatus:(SyncOperationState)state syncId:(NSUUID *)syncId message:(NSString*)message error:(NSError *)error {
    _state = state;
    _error = error;
    _message = message;

    SyncStatusLogEntry* entry = [SyncStatusLogEntry logWithState:state syncId:syncId message:message error:error];
    
    [self.log addObject:entry];
}

- (NSArray<SyncStatusLogEntry *> *)changeLog {
    return self.log.allObjects;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"[%@%@]", @(self.state), self.error ? [NSString stringWithFormat: @" Error: [%@]", self.error.description] : @""];
}

@end
