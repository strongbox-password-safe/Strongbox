//
//  CustomFieldTableCell.m
//  Strongbox-iOS
//
//  Created by Mark on 26/03/2019.
//  Copyright © 2019 Mark McGuill. All rights reserved.
//

#import "CustomFieldTableCell.h"
#import "ColoredStringHelper.h"
#import "SharedAppAndAutoFillSettings.h"

NSString *const CustomFieldCellHeightChanged = @"CustomFieldCellHeightChangedNotification";

@interface CustomFieldTableCell ()

@property (weak, nonatomic) IBOutlet UILabel *keyLabel;
@property (weak, nonatomic) IBOutlet UILabel *valueLabel;
@property (weak, nonatomic) IBOutlet UIButton *buttonShowHide;

@property NSString* _key;
@property NSString* _value;
@property BOOL _concealed;

@property BOOL _showShowHideButton;

@end

@implementation CustomFieldTableCell

- (NSString *)key {
    return self._key;
}

- (void)setKey:(NSString *)key {
    self._key = key;
    self.keyLabel.text = key;
}

- (NSString *)value {
    return self._value;
}

- (void)setValue:(NSString *)value {
    self._value = value;
    self.valueLabel.text = value;
}

- (BOOL)concealed {
    return self._concealed;
}

- (void)setConcealed:(BOOL)concealed {
    self._concealed = concealed;
    [self bindConcealed];
}

- (BOOL)isHideable {
    return self._showShowHideButton;
}
- (void)setIsHideable:(BOOL)showShowHideButton {
    self._showShowHideButton = showShowHideButton;
    self.buttonShowHide.hidden = !showShowHideButton;
}

- (IBAction)toggleShowHide:(id)sender {
    self._concealed = !self._concealed;
    [self bindConcealed];
}

- (void)bindConcealed {
    if(self._concealed) {
        [self.buttonShowHide setImage:[UIImage imageNamed:@"show"] forState:UIControlStateNormal];

        self.valueLabel.text = NSLocalizedString(@"generic_masked_protected_field_text", @"*****************");

        self.valueLabel.textColor = [UIColor lightGrayColor];
    }
    else {
        [self.buttonShowHide setImage:[UIImage imageNamed:@"hide"] forState:UIControlStateNormal];

        BOOL dark = NO;
        if (@available(iOS 12.0, *)) {
           dark = self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark;
        }
        BOOL colorBlind = SharedAppAndAutoFillSettings.sharedInstance.colorizeUseColorBlindPalette;

        self.valueLabel.attributedText = [ColoredStringHelper getColorizedAttributedString:self._value
                                                                                  colorize:self.colorize
                                                                                  darkMode:dark
                                                                                colorBlind:colorBlind
                                                                                      font:self.valueLabel.font];
    }

    [[NSNotificationCenter defaultCenter] postNotificationName:CustomFieldCellHeightChanged object:self];
}

@end
