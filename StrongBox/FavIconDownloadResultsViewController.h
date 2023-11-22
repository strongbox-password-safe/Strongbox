//
//  FavIconDownloadResultsViewController.h
//  Strongbox
//
//  Created by Mark on 27/11/2019.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "Model.h"
#import "FavIconBulkViewController.h"
#import "ConcurrentMutableDictionary.h"

NS_ASSUME_NONNULL_BEGIN

@interface FavIconDownloadResultsViewController : UITableViewController

@property Model* model;
@property NSArray<NSUUID*> *validNodes;
@property ConcurrentMutableDictionary<NSUUID*, NSArray<NodeIcon*>*>* nodeImagesMap;
@property NSArray<Node*> *nodes;

@property (nonatomic, copy) FavIconBulkDoneBlock onDone;

@end

NS_ASSUME_NONNULL_END
