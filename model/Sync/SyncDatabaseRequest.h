//
//  SyncDatabaseRequest.h
//  Strongbox
//
//  Created by Strongbox on 08/08/2020.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SyncParameters.h"
#import "SyncAndMergeSequenceManager.h"

NS_ASSUME_NONNULL_BEGIN

@interface SyncDatabaseRequest : NSObject

@property NSString* databaseId;
@property SyncParameters *parameters;
@property (copy) SyncAndMergeCompletionBlock completion;

@end

NS_ASSUME_NONNULL_END
