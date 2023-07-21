//
//  TotpCell.h
//  Strongbox-iOS
//
//  Created by Mark on 25/04/2019.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "OTPToken.h"

NS_ASSUME_NONNULL_BEGIN

@interface TotpCell : UITableViewCell

- (void)setItem:(OTPToken*)otpToken;
@property (nonatomic, copy, nullable) void (^onShowQrCode)(void);

@end

NS_ASSUME_NONNULL_END
