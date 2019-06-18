//
//  CustomFieldTableCell.m
//  Strongbox-iOS
//
//  Created by Mark on 26/03/2019.
//  Copyright © 2019 Mark McGuill. All rights reserved.
//

#import "ConfidentialTableCell.h"
#import "FontManager.h"
#import "ItemDetailsViewController.h"

@interface ConfidentialTableCell ()

@property (weak, nonatomic) IBOutlet UILabel *keyLabel;
@property (weak, nonatomic) IBOutlet UIButton *buttonRevealConceal;
@property (weak, nonatomic) IBOutlet UILabel *valueLabel;

@property NSString* _key;
@property NSString* _value;
@property BOOL _concealed;
@property BOOL _isConfidential;
@property BOOL _isEditable;

@end

@implementation ConfidentialTableCell

- (void)awakeFromNib {
    [super awakeFromNib];
    
    self.keyLabel.font = FontManager.sharedInstance.regularFont;
    self.keyLabel.adjustsFontForContentSizeCategory = YES;
    self.valueLabel.adjustsFontForContentSizeCategory = YES;
    
    [self prepareForReuse];
}

- (void)prepareForReuse {
    [super prepareForReuse];
    
    self._isConfidential = YES;
    self._concealed = NO;
    self._key = @"";
    self._value = @"";
    self.onConcealedChanged = nil;
    
    self.accessoryType = UITableViewCellAccessoryNone;
}

- (void)setKey:(NSString *)key value:(NSString*)value isConfidential:(BOOL)isConfidential concealed:(BOOL)concealed isEditable:(BOOL)isEditable {
    self._key = key;
    self._value = value;
    self._isConfidential = isConfidential;
    self._concealed = concealed;
    self._isEditable = isEditable;

    [self bindUiToSettings];
}

- (IBAction)toggleRevealOrConceal:(id)sender {
    self._concealed = !self._concealed;
    
    if(self.onConcealedChanged) {
        self.onConcealedChanged(self._concealed);
    }
    
    [self bindUiToSettings];
}

- (void)bindUiToSettings {
    self.keyLabel.text = self._key;
    self.keyLabel.textColor = UIColor.darkGrayColor;
    self.valueLabel.text = self._value;
    self.buttonRevealConceal.hidden = !self._isConfidential || self._isEditable;
    
    if(self._concealed) {
        [self.buttonRevealConceal setImage:[UIImage imageNamed:@"visible"] forState:UIControlStateNormal];
        self.valueLabel.text = @"*****************";
        self.valueLabel.textColor = [UIColor lightGrayColor];
        self.valueLabel.font = FontManager.sharedInstance.configuredValueFont;
    }
    else {
        [self.buttonRevealConceal setImage:[UIImage imageNamed:@"invisible"] forState:UIControlStateNormal];
        
        self.valueLabel.textColor = [UIColor darkTextColor];
        self.valueLabel.font = self._isConfidential ? FontManager.sharedInstance.easyReadFont : FontManager.sharedInstance.configuredValueFont;
    }

    [[NSNotificationCenter defaultCenter] postNotificationName:CellHeightsChangedNotification object:self];
}

@end
