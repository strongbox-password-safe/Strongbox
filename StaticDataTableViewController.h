//
//  StaticTableViewController.h
//  StaticTableViewController 2.0
//
//  Created by Peter Paulis on 31.1.2013.
//  Copyright (c) 2013 Peter Paulis. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface StaticDataTableViewController : UITableViewController


@property (nonatomic, assign) UITableViewRowAnimation insertTableViewRowAnimation;

@property (nonatomic, assign) UITableViewRowAnimation reloadTableViewRowAnimation;

@property (nonatomic, assign) UITableViewRowAnimation deleteTableViewRowAnimation;


// Shown / Hidden
- (void)cell:(nonnull UITableViewCell *)cell setHidden:(BOOL)hidden;

- (void)cells:(nonnull NSArray *)cells setHidden:(BOOL)hidden;

- (BOOL)isCellHidden:(nonnull UITableViewCell *)cell;


// Height
- (void)cell:(nonnull UITableViewCell *)cell setHeight:(CGFloat)height;

- (void)cells:(nonnull NSArray *)cells setHeight:(CGFloat)height;


// Update
- (void)updateCell:(nonnull UITableViewCell *)cell;

- (void)updateCells:(nonnull NSArray *)cells;


// Reload
// never call [self.tableView reloadData] directly
// doing so will lead to data inconsistency
// ALWAYS! use this method for reload!
- (void)reloadDataAnimated:(BOOL)animated;

- (void)reloadDataAnimated:(BOOL)animated insertAnimation:(UITableViewRowAnimation)insertAnimation reloadAnimation:(UITableViewRowAnimation)reloadAnimation deleteAnimation:(UITableViewRowAnimation)deleteAnimation;


// you may want to overwrite these two methods in your subclass, to provide custom logic (eg. force the header or footer to be shown, even when no cell are vissible)
- (BOOL)showHeaderForSection:(NSInteger)section vissibleRows:(NSInteger)vissibleRows;
- (BOOL)showFooterForSection:(NSInteger)section vissibleRows:(NSInteger)vissibleRows;


// Depracated
@property (nonatomic, assign) BOOL animateSectionHeaders DEPRECATED_ATTRIBUTE;
@property (nonatomic, assign) BOOL hideSectionsWithHiddenRows DEPRECATED_ATTRIBUTE; // use showHeaderForSection:vissibleRows: and showFooterForSection::vissibleRows:
- (BOOL)cellIsHidden:(nonnull UITableViewCell *)cell DEPRECATED_ATTRIBUTE; // use isCellHidden:

@end
