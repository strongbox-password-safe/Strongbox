//
//  SwitchTableViewCell.h
//  Strongbox
//
//  Created by Strongbox on 01/06/2020.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface SwitchTableViewCell : UITableViewCell

@property (readonly) BOOL on;
- (void)set:(NSString*)text on:(BOOL)on onChanged:(void(^)(BOOL on))onChanged;
- (void)set:(NSString*)text on:(BOOL)on enabled:(BOOL)enabled onChanged:(void(^)(BOOL on))onChanged;

@end

NS_ASSUME_NONNULL_END
