//
//  AuditDrillDownController.h
//  Strongbox
//
//  Created by Strongbox on 01/06/2020.
//  Copyright © 2020 Mark McGuill. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "Model.h"

NS_ASSUME_NONNULL_BEGIN

@interface AuditDrillDownController : UITableViewController

@property Model* model;
@property Node* item;
@property (nonatomic, copy) void (^onDone)(BOOL showAllAuditIssues);
@property BOOL hideShowAllAuditIssues;

@end

NS_ASSUME_NONNULL_END
