//
//  DatabaseCell.h
//  Strongbox
//
//  Created by Mark on 30/07/2019.
//  Copyright © 2019 Mark McGuill. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "SafeMetaData.h"

NS_ASSUME_NONNULL_BEGIN

extern NSString* const kDatabaseCell;

@interface DatabaseCell : UITableViewCell

- (void)populateCell:(SafeMetaData*)database disabled:(BOOL)disabled;
- (void)populateAutoFillCell:(SafeMetaData*)database liveIsPossible:(BOOL)liveIsPossible disabled:(BOOL)disabled; // TODO: Remove once Auto-Fill is local only

@end

NS_ASSUME_NONNULL_END
