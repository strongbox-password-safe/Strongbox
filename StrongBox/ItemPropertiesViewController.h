//
//  GroupDetailsController.h
//  Strongbox
//
//  Created by Strongbox on 02/11/2020.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "Model.h"

NS_ASSUME_NONNULL_BEGIN

@interface ItemPropertiesViewController : UITableViewController

@property Model* model;
@property Node* item;
@property (nonatomic, copy) void (^updateDatabase)(void);

@end

NS_ASSUME_NONNULL_END
