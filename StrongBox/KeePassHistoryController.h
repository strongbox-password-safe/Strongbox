//
//  KeePassHistoryController.h
//  Strongbox-iOS
//
//  Created by Mark on 07/03/2019.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "Node.h"
#import "Model.h"

NS_ASSUME_NONNULL_BEGIN

@interface KeePassHistoryController : UITableViewController

@property NSArray<Node*>* historicalItems;
@property Model* viewModel;

@property (nonatomic, copy) void (^deleteHistoryItem)(Node* historicalNode);
@property (nonatomic, copy) void (^restoreToHistoryItem)(Node* historicalNode);

@end

NS_ASSUME_NONNULL_END
