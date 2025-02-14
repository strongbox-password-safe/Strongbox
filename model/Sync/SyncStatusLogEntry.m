//
//  SyncStatusLogEntry.m
//  Strongbox
//
//  Created by Strongbox on 08/08/2020.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import "SyncStatusLogEntry.h"
#import "NSDate+Extensions.h"

@implementation SyncStatusLogEntry

+ (instancetype)logWithState:(SyncOperationState)state syncId:(NSUUID *)syncId message:(NSString *)message error:(NSError *)error {
    return [[SyncStatusLogEntry alloc] initWithState:state syncId:syncId message:message error:error];
}

- (instancetype)initWithState:(SyncOperationState)state syncId:(NSUUID *)syncId message:(NSString *)message error:(NSError *)error {
    self = [super init];
    
    if (self) {
        _timestamp = NSDate.date;
        _state = state;
        _message = message;
        _error = error;
        _syncId = syncId;
    }
    
    return self;
}

- (NSString *)description {
    

    return [NSString stringWithFormat:@"%@: %@", self.timestamp.friendlyDateTimeStringPrecise, self.error ? self.error : self.message];
}

@end
