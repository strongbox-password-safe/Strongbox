//
//  BrowseTableViewCellHelper.h
//  Strongbox
//
//  Created by Mark on 24/04/2020.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "Node.h"
#import "Model.h"

NS_ASSUME_NONNULL_BEGIN

@interface BrowseTableViewCellHelper : NSObject

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithModel:(Model*)model tableView:(UITableView*)tableView NS_DESIGNATED_INITIALIZER;

- (UITableViewCell*)getTagCell:(NSIndexPath*)indexPath tag:(NSString*)tag;

- (UITableViewCell *)getBrowseCellForNode:(Node*)node indexPath:(NSIndexPath*)indexPath showLargeTotpCell:(BOOL)totp showGroupLocation:(BOOL)showGroupLocation;

- (UITableViewCell *)getBrowseCellForNode:(Node*)node
                                indexPath:(NSIndexPath*)indexPath
                        showLargeTotpCell:(BOOL)showLargeTotpCell
                        showGroupLocation:(BOOL)showGroupLocation
                    groupLocationOverride:(NSString*_Nullable)groupLocationOverride
                            accessoryType:(UITableViewCellAccessoryType)accessoryType;

- (UITableViewCell *)getBrowseCellForNode:(Node*)node
                                indexPath:(NSIndexPath*)indexPath
                        showLargeTotpCell:(BOOL)showLargeTotpCell
                        showGroupLocation:(BOOL)showGroupLocation
                    groupLocationOverride:(NSString*_Nullable)groupLocationOverride
                            accessoryType:(UITableViewCellAccessoryType)accessoryType
                                  noFlags:(BOOL)noFlags;

- (UITableViewCell *)getBrowseCellForNode:(Node*)node
                                indexPath:(NSIndexPath*)indexPath
                        showLargeTotpCell:(BOOL)showLargeTotpCell
                        showGroupLocation:(BOOL)showGroupLocation
                    groupLocationOverride:(NSString*_Nullable)groupLocationOverride
                            accessoryType:(UITableViewCellAccessoryType)accessoryType
                                  noFlags:(BOOL)noFlags
                      showGroupChildCount:(BOOL)showGroupChildCount;

- (UITableViewCell *)getBrowseCellForNode:(Node*)node
                                indexPath:(NSIndexPath*)indexPath
                        showLargeTotpCell:(BOOL)showLargeTotpCell
                        showGroupLocation:(BOOL)showGroupLocation
                    groupLocationOverride:(NSString*_Nullable)groupLocationOverride
                            accessoryType:(UITableViewCellAccessoryType)accessoryType
                                  noFlags:(BOOL)noFlags
                      showGroupChildCount:(BOOL)showGroupChildCount
                         subtitleOverride:(NSNumber*_Nullable)subtitleOverride;

@end

NS_ASSUME_NONNULL_END
