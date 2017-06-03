//
//  SelectDestinationGroupController.h
//  StrongBox
//
//  Created by Mark on 25/11/2014.
//  Copyright (c) 2014 Mark McGuill. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "Model.h"
#import "Group.h"

@interface SelectDestinationGroupController : UITableViewController

@property (nonatomic, strong) Model *viewModel;
@property Group *currentGroup;
@property NSArray *itemsToMove;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *buttonMove;

@end
