//
//  GroupDetailsController.h
//  Strongbox
//
//  Created by Strongbox on 02/11/2020.
//  Copyright © 2020 Mark McGuill. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "Model.h"

NS_ASSUME_NONNULL_BEGIN

@interface ItemPropertiesViewController : UITableViewController

@property Model* model;
@property Node* item;

@end

NS_ASSUME_NONNULL_END
