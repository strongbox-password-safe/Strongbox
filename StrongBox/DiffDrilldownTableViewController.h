//
//  DiffDrilldownTableViewController.h
//  Strongbox
//
//  Created by Strongbox on 15/12/2020.
//  Copyright © 2020 Mark McGuill. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "Pair.h"
#import "Node.h"
#import "Model.h"

NS_ASSUME_NONNULL_BEGIN

@interface DiffDrilldownTableViewController : UITableViewController

@property Model* firstDatabase;
@property Model* secondDatabase;

@property BOOL isMergeDiff;

@property Pair<Node*, Node*>* diffPair;

@end

NS_ASSUME_NONNULL_END
