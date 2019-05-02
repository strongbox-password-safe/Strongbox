//
//  ItemDetailsViewController.h
//  test-new-ui
//
//  Created by Mark on 18/04/2019.
//  Copyright © 2019 Mark McGuill. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "Node.h"
#import "Model.h"

NS_ASSUME_NONNULL_BEGIN

extern NSString *const CellHeightsChangedNotification;

@interface ItemDetailsViewController : UITableViewController

@property BOOL createNewItem;
@property Node* parentGroup;
@property Node*_Nullable item;
@property BOOL readOnly;
@property Model* databaseModel;

@end

NS_ASSUME_NONNULL_END
