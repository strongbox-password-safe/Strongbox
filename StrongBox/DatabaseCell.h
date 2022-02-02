//
//  DatabaseCell.h
//  Strongbox
//
//  Created by Mark on 30/07/2019.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "DatabasePreferences.h"

NS_ASSUME_NONNULL_BEGIN

extern NSString* const kDatabaseCell;

@interface DatabaseCell : UITableViewCell

- (void)populateCell:(DatabasePreferences*)database;
- (void)populateCell:(DatabasePreferences *)database disabled:(BOOL)disabled;
- (void)populateCell:(DatabasePreferences*)database disabled:(BOOL)disabled autoFill:(BOOL)autoFill;

@end

NS_ASSUME_NONNULL_END
