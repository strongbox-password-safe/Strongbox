//
//  BrowseItemTotpCell.h
//  Strongbox-iOS
//
//  Created by Mark on 17/06/2019.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "OTPToken.h"

NS_ASSUME_NONNULL_BEGIN

@interface BrowseItemTotpCell : UITableViewCell

- (void)setItem:(NSString*)title subtitle:(NSString*)subtitle icon:(UIImage*)icon expired:(BOOL)expired otpToken:(OTPToken*)otpToken hideIcon:(BOOL)hideIcon;

@end

NS_ASSUME_NONNULL_END
