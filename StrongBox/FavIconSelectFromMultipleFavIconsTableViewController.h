//
//  FavIconSelectFromMultipleFavIconsTableViewController.h
//  Strongbox
//
//  Created by Mark on 30/11/2019.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "Node.h"

NS_ASSUME_NONNULL_BEGIN

@interface FavIconSelectFromMultipleFavIconsTableViewController : UITableViewController

@property Node* node;
@property NSArray<UIImage*> *images;
@property NSUInteger selectedIndex;

@property (nonatomic, copy) void (^onChangedSelection)(NSUInteger index);

@end

NS_ASSUME_NONNULL_END
