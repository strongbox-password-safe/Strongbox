//
//  SyncDiffReport.h
//  Strongbox
//
//  Created by Strongbox on 20/10/2020.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Node.h"
#import "MMcGPair.h"
#import "DiffSummary.h"

NS_ASSUME_NONNULL_BEGIN

@interface MergeDryRunReport : NSObject

@property BOOL success;
@property DiffSummary* diff;

@end

NS_ASSUME_NONNULL_END
