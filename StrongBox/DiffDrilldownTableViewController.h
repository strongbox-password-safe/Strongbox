//
//  DiffDrilldownTableViewController.h
//  Strongbox
//
//  Created by Strongbox on 15/12/2020.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "MMcGPair.h"
#import "Node.h"
#import "Model.h"

NS_ASSUME_NONNULL_BEGIN

@interface DiffDrilldownTableViewController : UITableViewController

@property Model* firstDatabase;
@property Model* secondDatabase;

@property BOOL isMergeDiff;

@property MMcGPair<Node*, Node*>* diffPair;

@end

NS_ASSUME_NONNULL_END
