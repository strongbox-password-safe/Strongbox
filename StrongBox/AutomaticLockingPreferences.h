//
//  AutomaticLockingPreferences.h
//  Strongbox
//
//  Created by Strongbox on 10/11/2021.
//  Copyright © 2021 Mark McGuill. All rights reserved.
//

#import "Model.h"
#import "StaticDataTableViewController.h"

NS_ASSUME_NONNULL_BEGIN

@interface AutomaticLockingPreferences : StaticDataTableViewController

+ (instancetype)fromStoryboardWithModel:(Model*)model;

@property Model* viewModel;

@end

NS_ASSUME_NONNULL_END
