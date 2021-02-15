//
//  SwitchTableViewCell.m
//  Strongbox
//
//  Created by Strongbox on 01/06/2020.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import "SwitchTableViewCell.h"

@interface SwitchTableViewCell ()

@property (weak, nonatomic) IBOutlet UILabel *labelText;
@property (weak, nonatomic) IBOutlet UISwitch *switchOnOff;
@property (nonatomic, copy) void (^onChanged)(BOOL);

@end

@implementation SwitchTableViewCell

- (void)prepareForReuse {
    [super prepareForReuse];
    
    self.switchOnOff.on = NO;
    self.labelText.text = @"";
    self.onChanged = nil;
}

- (void)set:(NSString *)text on:(BOOL)on onChanged:(void (^)(BOOL))onChanged {
    self.labelText.text = text;
    self.switchOnOff.on = on;
    self.onChanged = onChanged;
}

- (BOOL)on {
    return self.switchOnOff.on;
}

- (IBAction)onSwitchOnOff:(id)sender {
    if (self.onChanged) {
        self.onChanged(self.on);
    }
}

@end
