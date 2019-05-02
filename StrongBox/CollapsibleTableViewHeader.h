//
//  CollapsibleTableViewHeader.h
//  Strongbox-iOS
//
//  Created by Mark on 01/05/2019.
//  Copyright © 2019 Mark McGuill. All rights reserved.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface CollapsibleTableViewHeader : UITableViewHeaderFooterView

@property (nonatomic, copy) void (^onToggleSection)(void);
- (void)setCollapsed:(BOOL)collapsed;

@end

NS_ASSUME_NONNULL_END
