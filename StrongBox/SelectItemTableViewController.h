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
@property NSInteger currentlySelectedIndex;
@property (nonatomic, copy) void (^onDone)(BOOL success, NSInteger selectedIndex);

@end

NS_ASSUME_NONNULL_END
