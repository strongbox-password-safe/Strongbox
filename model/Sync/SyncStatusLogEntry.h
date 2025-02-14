//
//  SyncStatusLogEntry.h
//  Strongbox
//
//  Created by Strongbox on 08/08/2020.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SyncOperationState.h"

NS_ASSUME_NONNULL_BEGIN

@interface SyncStatusLogEntry : NSObject

+ (instancetype)logWithState:(SyncOperationState)state syncId:(NSUUID*)syncId message:(NSString*_Nullable)message error:(NSError*_Nullable)error;

@property (readonly) NSDate* timestamp;
@property (readonly) NSUUID* syncId;
@property (readonly) SyncOperationState state;
@property (readonly, nullable) NSError* error;
@property (readonly, nullable) NSString* message;

@end

NS_ASSUME_NONNULL_END
