//
//  AsyncUpdateJob.h
//  MacBox
//
//  Created by Strongbox on 30/11/2021.
//  Copyright © 2021 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Model.h"

NS_ASSUME_NONNULL_BEGIN

typedef enum : NSUInteger {
    kAsyncJobTypeSerializeOnly,
    kAsyncJobTypeSyncOnly,
    kAsyncJobTypeBoth,
} AsyncJobType;

@interface AsyncUpdateJob : NSObject

@property DatabaseModel* snapshot;
@property (nonatomic, copy, nullable) AsyncUpdateCompletion completion;
@property AsyncJobType jobType;

@end

NS_ASSUME_NONNULL_END
