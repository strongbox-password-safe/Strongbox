//
//  SelectDestinationGroupController.h
//  StrongBox
//
//  Created by Mark on 25/11/2014.
//  Copyright (c) 2014 Mark McGuill. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "Model.h"

@interface SelectDestinationGroupController : UITableViewController

@property (nonatomic, strong, nonnull) Model *viewModel;
@property Node * _Nonnull currentGroup;
@property NSArray<Node*> * _Nonnull itemsToMove;
@property (weak, nonatomic, nullable) IBOutlet UIBarButtonItem * buttonMove;

@end
