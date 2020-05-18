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

@property BOOL multipleSelectMode;
@property BOOL multipleSelectDisallowEmpty;

@property BOOL groupedMode;
@property NSArray<NSString*>* groupHeaders;
@property NSArray<NSArray<NSString*>*>* groupItems;
@property NSArray<NSIndexSet*>* selectedIndexPaths; 

@property (nonatomic, copy) void (^onSelectionChange)(NSArray<NSIndexSet*>* selectedIndices);

@end

NS_ASSUME_NONNULL_END
