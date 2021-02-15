//
//  SortOrderTableViewController.h
//  Strongbox-iOS
//
//  Created by Mark on 11/06/2019.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import "StaticDataTableViewController.h"
#import "BrowseSortField.h"
#import "AbstractDatabaseFormatAdaptor.h"

NS_ASSUME_NONNULL_BEGIN

@interface SortOrderTableViewController : StaticDataTableViewController

@property (nonatomic, copy) void (^onChangedOrder)(BrowseSortField field, BOOL descending, BOOL foldersSeparately);

@property BrowseSortField field;
@property BOOL descending;
@property BOOL foldersSeparately;

@property DatabaseFormat format;

@end

NS_ASSUME_NONNULL_END
