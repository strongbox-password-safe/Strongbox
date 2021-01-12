//
//  MergeOptions.h
//  Strongbox
//
//  Created by Strongbox on 03/01/2021.
//  Copyright © 2021 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface MergeOptions : NSObject

@property BOOL keePassGroupTitleRules; // PwSafe Group Naming
@property BOOL doNotCompareGroups; // PwSafe

@end

NS_ASSUME_NONNULL_END
