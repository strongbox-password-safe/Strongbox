//
//  AuditDrillDownController.h
//  Strongbox
//
//  Created by Strongbox on 01/06/2020.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "Model.h"

NS_ASSUME_NONNULL_BEGIN

@interface AuditDrillDownController : UITableViewController

+ (UINavigationController*)fromStoryboard;

@property Model* model;
@property NSUUID* itemId;

@property (nonatomic, copy) void (^updateDatabase)(void);

@end

NS_ASSUME_NONNULL_END
