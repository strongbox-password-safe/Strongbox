//
//  BrowseItemTotpCell.h
//  Strongbox-iOS
//
//  Created by Mark on 17/06/2019.
//  Copyright © 2019 Mark McGuill. All rights reserved.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface BrowseItemTotpCell : UITableViewCell

@property (weak, nonatomic) IBOutlet UILabel *labelOtp;
@property (weak, nonatomic) IBOutlet UILabel *labelTitle;
@property (weak, nonatomic) IBOutlet UILabel *labelUsername;
@property (weak, nonatomic) IBOutlet UIImageView *icon;

@end

NS_ASSUME_NONNULL_END
