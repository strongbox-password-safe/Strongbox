//
//  SelectDestinationGroupController.h
//  StrongBox
//
//  Created by Mark on 25/11/2014.
//  Copyright (c) 2014 Mark McGuill. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "Model.h"

NS_ASSUME_NONNULL_BEGIN

@interface SelectDestinationGroupController : UITableViewController

@property (nonatomic, strong, nonnull) Model *viewModel;
@property Node * _Nonnull currentGroup;
@property NSArray<Node*> * _Nonnull itemsToMove;

@property (nonatomic, copy, nonnull) void (^onDone)(BOOL userCancelled, BOOL localWasChanged, NSError* error);

@end

NS_ASSUME_NONNULL_END
