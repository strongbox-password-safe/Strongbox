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

NS_ASSUME_NONNULL_BEGIN

@interface FavIconDownloadResultsViewController : UITableViewController

@property NSDictionary<NSURL*, NSArray<UIImage*>*>* results;
@property NSArray<Node*> *nodes;

@property NSURL* singleNodeUrlOverride;

@property (nonatomic, copy) FavIconBulkDoneBlock onDone;

@end

NS_ASSUME_NONNULL_END
