//
//  SelectItemTableViewController.h
//  Strongbox-iOS
//
//  Created by Mark on 30/05/2019.
//  Copyright © 2019 Mark McGuill. All rights reserved.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface SelectItemTableViewController : UITableViewController

@property NSArray<NSString*>* items;
@property NSIndexSet *selected;

@property (nonatomic, copy) void (^onSelectionChanged)(NSIndexSet* selectedIndices);

@property BOOL multipleSelectMode;
@property BOOL multipleSelectDisallowEmpty;

@end

NS_ASSUME_NONNULL_END
