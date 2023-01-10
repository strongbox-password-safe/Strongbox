//
//  PropertySwitchTableViewCell.h
//  Strongbox
//
//  Created by Strongbox on 20/01/2021.
//  Copyright © 2021 Mark McGuill. All rights reserved.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

extern NSString* const kPropertySwitchTableViewCellId;

typedef void (^OnToggledSwitchBlock)(BOOL currentState);

@interface PropertySwitchTableViewCell : UITableViewCell

@property (weak, nonatomic) IBOutlet UILabel *titleLabel;
@property (weak, nonatomic) IBOutlet UILabel *subtitleLabel;
@property (weak, nonatomic) IBOutlet UISwitch *switchBool;
@property (copy, nullable) OnToggledSwitchBlock onToggledSwitch;

@end

NS_ASSUME_NONNULL_END
