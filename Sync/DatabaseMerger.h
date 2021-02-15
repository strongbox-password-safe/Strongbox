//
//  DatabaseSynchronizer.h
//  Strongbox
//
//  Created by Strongbox on 18/10/2020.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "DatabaseModel.h"
#import "MergeDryRunReport.h"

NS_ASSUME_NONNULL_BEGIN

@interface DatabaseMerger : NSObject

+ (instancetype)mergerFor:(DatabaseModel *)mine theirs:(DatabaseModel *)theirs;

- (MergeDryRunReport *)dryRun;

- (BOOL)merge;

@end

NS_ASSUME_NONNULL_END
