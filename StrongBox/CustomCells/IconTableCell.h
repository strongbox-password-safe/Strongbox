//
//  IconTableCell.h
//  Strongbox-iOS
//
//  Created by Mark on 25/04/2019.
//  Copyright © 2019 Mark McGuill. All rights reserved.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface IconTableCell : UITableViewCell

@property (weak, nonatomic) IBOutlet UIImageView *iconImage;
@property (nonatomic, copy, nullable) void (^onIconTapped)(void);

@end

NS_ASSUME_NONNULL_END
