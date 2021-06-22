//
//  PinsConfigurationController.h
//  Strongbox-iOS
//
//  Created by Mark on 11/01/2019.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "Model.h"
#import "StaticDataTableViewController.h"

NS_ASSUME_NONNULL_BEGIN

@interface PinsConfigurationController : StaticDataTableViewController

@property (nonatomic, nonnull) Model *viewModel;

@end

NS_ASSUME_NONNULL_END
