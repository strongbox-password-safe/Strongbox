//
//  PasswordGenerationViewController.h
//  Strongbox
//
//  Created by Mark on 29/06/2019.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import "StaticDataTableViewController.h"
#import "PasswordGenerationConfig.h"
NS_ASSUME_NONNULL_BEGIN

@interface PasswordGenerationViewController : StaticDataTableViewController

@property (nonatomic, copy) void (^onDone)(void);

@end

NS_ASSUME_NONNULL_END
