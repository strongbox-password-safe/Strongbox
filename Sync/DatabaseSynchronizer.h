//
//  DatabaseSynchronizer.h
//  Strongbox
//
//  Created by Strongbox on 18/10/2020.
//  Copyright © 2020 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "DatabaseModel.h"

NS_ASSUME_NONNULL_BEGIN

@interface DatabaseSynchronizer : NSObject

+ (instancetype)newSynchronizerFor:(DatabaseModel *)mine theirs:(DatabaseModel *)theirs;

- (void)getDiff;

@end

NS_ASSUME_NONNULL_END
