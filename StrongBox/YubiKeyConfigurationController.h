//
//  YubiKeyConfigurationController.h
//  Strongbox
//
//  Created by Mark on 10/02/2020.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "StaticDataTableViewController.h"
#import "YubiKeyHardwareConfiguration.h"

NS_ASSUME_NONNULL_BEGIN

@interface YubiKeyConfigurationController : UITableViewController

@property (nonatomic, copy) void (^onDone)(YubiKeyHardwareConfiguration* config);
@property (nullable) YubiKeyHardwareConfiguration* initialConfiguration;

@end

NS_ASSUME_NONNULL_END
