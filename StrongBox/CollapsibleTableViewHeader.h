//
//  CollapsibleTableViewHeader.h
//  Strongbox-iOS
//
//  Created by Mark on 01/05/2019.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface CollapsibleTableViewHeader : UITableViewHeaderFooterView

@property (nonatomic, copy) void (^onToggleSection)(void);

- (instancetype)initWithOnCopy:(void(^ _Nullable )(void))onCopy;
- (void)setCollapsed:(BOOL)collapsed;

@end

NS_ASSUME_NONNULL_END
