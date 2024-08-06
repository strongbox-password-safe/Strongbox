//
//  ConvenienceUnlockPreferences.h
//  Strongbox
//
//  Created by Strongbox on 10/05/2021.
//  Copyright © 2021 Mark McGuill. All rights reserved.
//

#import "StaticDataTableViewController.h"
#import "Model.h"

NS_ASSUME_NONNULL_BEGIN

@interface ConvenienceUnlockPreferences : StaticDataTableViewController

+ (UINavigationController*)fromStoryboardWithModel:(Model*)model;

@property Model* viewModel;

@end

NS_ASSUME_NONNULL_END
