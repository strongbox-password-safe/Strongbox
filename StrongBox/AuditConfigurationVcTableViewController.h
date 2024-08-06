//
//  AuditConfigurationVcTableViewController.h
//  Strongbox
//
//  Created by Mark on 24/04/2020.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "Model.h"
#import "StaticDataTableViewController.h"
NS_ASSUME_NONNULL_BEGIN

@interface AuditConfigurationVcTableViewController : StaticDataTableViewController

+ (instancetype)fromStoryboard;

@property Model* model;
@property (nonatomic, copy) void (^updateDatabase)(void);

@end

NS_ASSUME_NONNULL_END
