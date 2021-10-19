//
//  UITableViewTemp.h
//  Strongbox
//
//  Created by Strongbox on 28/10/2020.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface ClosureSleeve : NSObject

- (instancetype)initWithAction:(dispatch_block_t)action;
- (void)act;

@end

@interface UITableView (EmptyDataSet)

- (void)setEmptyTitle:(NSAttributedString*_Nullable)title;
- (void)setEmptyTitle:(NSAttributedString*_Nullable)title description:(NSAttributedString*_Nullable)description;
- (void)setEmptyTitle:(NSAttributedString*_Nullable)title description:(NSAttributedString*_Nullable)description buttonTitle:(NSAttributedString*_Nullable)buttonTitle buttonAction:(dispatch_block_t _Nullable)buttonAction;

- (void)setEmptyTitle:(NSAttributedString *_Nullable)title
          description:(NSAttributedString *_Nullable)description
          buttonTitle:(NSAttributedString *_Nullable)buttonTitle
        bigBlueBounce:(BOOL)bigBlueBounce
         buttonAction:(dispatch_block_t)buttonAction;

@end

NS_ASSUME_NONNULL_END
