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



- (void)cell:(nonnull UITableViewCell *)cell setHidden:(BOOL)hidden;

- (void)cells:(nonnull NSArray *)cells setHidden:(BOOL)hidden;

- (BOOL)isCellHidden:(nonnull UITableViewCell *)cell;



- (void)cell:(nonnull UITableViewCell *)cell setHeight:(CGFloat)height;

- (void)cells:(nonnull NSArray *)cells setHeight:(CGFloat)height;



- (void)updateCell:(nonnull UITableViewCell *)cell;

- (void)updateCells:(nonnull NSArray *)cells;






- (void)reloadDataAnimated:(BOOL)animated;

- (void)reloadDataAnimated:(BOOL)animated insertAnimation:(UITableViewRowAnimation)insertAnimation reloadAnimation:(UITableViewRowAnimation)reloadAnimation deleteAnimation:(UITableViewRowAnimation)deleteAnimation;



- (BOOL)showHeaderForSection:(NSInteger)section vissibleRows:(NSInteger)vissibleRows;
- (BOOL)showFooterForSection:(NSInteger)section vissibleRows:(NSInteger)vissibleRows;



@property (nonatomic, assign) BOOL animateSectionHeaders DEPRECATED_ATTRIBUTE;
@property (nonatomic, assign) BOOL hideSectionsWithHiddenRows DEPRECATED_ATTRIBUTE; 
- (BOOL)cellIsHidden:(nonnull UITableViewCell *)cell DEPRECATED_ATTRIBUTE; 

@end
