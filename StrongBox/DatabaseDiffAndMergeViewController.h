//
//  ShowMergeDiffTableViewController.h
//  Strongbox
//
//  Created by Mark on 14/12/2020.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "Model.h"

NS_ASSUME_NONNULL_BEGIN

@interface DatabaseDiffAndMergeViewController : UITableViewController

@property Model* firstDatabase;
@property Model* secondDatabase;

@property BOOL isCompareForMerge;
@property BOOL isSyncInitiated; 

@property (nonatomic, copy) void (^onDone)(BOOL mergeRequested, Model*_Nullable first, Model*_Nullable second);

@end

NS_ASSUME_NONNULL_END
