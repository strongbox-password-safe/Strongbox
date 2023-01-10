//
//  PropertySwitchTableViewCell.m
//  Strongbox
//
//  Created by Strongbox on 20/01/2021.
//  Copyright © 2021 Mark McGuill. All rights reserved.
//

#import "PropertySwitchTableViewCell.h"

NSString* const kPropertySwitchTableViewCellId = @"PropertySwitchTableViewCell";

@implementation PropertySwitchTableViewCell

- (void)prepareForReuse {
    [super prepareForReuse];
    
    self.titleLabel.text = @"";
    self.subtitleLabel.text = @"";
    self.switchBool.hidden = NO;
    self.accessoryType = UITableViewCellAccessoryNone;
    self.selectionStyle = UITableViewCellSelectionStyleNone;
}

- (IBAction)onSwitchValueChanged:(id)sender {
    if (self.onToggledSwitch) {
        self.onToggledSwitch(self.switchBool.on);
    }
}

@end
