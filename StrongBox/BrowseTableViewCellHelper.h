//
//  BrowseTableViewCellHelper.h
//  Strongbox
//
//  Created by Mark on 24/04/2020.
//  Copyright © 2020 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "Node.h"
#import "Model.h"

NS_ASSUME_NONNULL_BEGIN

@interface BrowseTableViewCellHelper : NSObject

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithModel:(Model*)model tableView:(UITableView*)tableView NS_DESIGNATED_INITIALIZER;

- (UITableViewCell *)getBrowseCellForNode:(Node*)node indexPath:(NSIndexPath*)indexPath totp:(BOOL)totp showGroupLocation:(BOOL)showGroupLocation;

@end

NS_ASSUME_NONNULL_END
