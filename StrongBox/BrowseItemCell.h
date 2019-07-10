//
//  BrowseItemCell.h
//  Strongbox
//
//  Created by Mark on 10/05/2019.
//  Copyright © 2019 Mark McGuill. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "OTPToken.h"

NS_ASSUME_NONNULL_BEGIN

@interface BrowseItemCell : UITableViewCell

@property (weak, nonatomic) IBOutlet UILabel *otpLabel;

- (void)setGroup:(NSString *)title icon:(UIImage*)icon childCount:(NSString*)childCount italic:(BOOL)italic groupLocation:(NSString*)groupLocation;
- (void)setGroup:(NSString *)title icon:(UIImage*)icon childCount:(NSString*)childCount italic:(BOOL)italic groupLocation:(NSString*)groupLocation tintColor:(UIColor* _Nullable )tintColor;

- (void)setRecord:(NSString*)title subtitle:(NSString*)subtitle icon:(UIImage*)icon groupLocation:(NSString*)groupLocation flags:(NSString*)flags otpToken:(OTPToken*)otpToken;

@end

NS_ASSUME_NONNULL_END
