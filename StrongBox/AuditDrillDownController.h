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

@property Model* model;
@property NSUUID* itemId;
@property (nonatomic, copy) void (^onDone)(BOOL showAllAuditIssues, __weak UIViewController* viewControllerToDismiss);
@property BOOL hideShowAllAuditIssues;

@end

NS_ASSUME_NONNULL_END
