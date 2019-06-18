//
//  GenericKeyValueTableViewCell.m
//  test-new-ui
//
//  Created by Mark on 18/04/2019.
//  Copyright © 2019 Mark McGuill. All rights reserved.
//

#import "GenericKeyValueTableViewCell.h"
#import "FontManager.h"

@interface GenericKeyValueTableViewCell ()

@property (weak, nonatomic) IBOutlet UIView *horizontalLine;
@property (weak, nonatomic) IBOutlet UILabel *keyLabel;
@property (weak, nonatomic) IBOutlet AutoCompleteTextField *valueText;
@property (weak, nonatomic) IBOutlet UIButton *rightAccessoryButton;

@property BOOL selectAllOnEdit;

@end

@implementation GenericKeyValueTableViewCell

- (void)awakeFromNib {
    [super awakeFromNib];

    self.horizontalLine.backgroundColor = UIColor.blueColor;
    
    self.keyLabel.font = FontManager.sharedInstance.regularFont;
    self.keyLabel.adjustsFontForContentSizeCategory = YES;
    
    self.valueText.adjustsFontForContentSizeCategory = YES;
    self.valueText.onEdited = ^(NSString * _Nonnull text) {
        [self onValueEdited];
    };
    
    self.selectAllOnEdit = NO;
}

- (void)prepareForReuse {
    [super prepareForReuse];

    self.selectAllOnEdit = NO;
    
    self.keyLabel.text = @"";
    self.valueText.text = @"";
    self.valueText.tag = 0;
    self.valueText.enabled = NO;
    self.valueText.placeholder = @"";
    self.valueText.font = FontManager.sharedInstance.configuredValueFont;
    
    self.horizontalLine.backgroundColor = UIColor.blueColor;
    
    self.onEdited = nil;
    self.showUiValidationOnEmpty = NO;
    self.suggestionProvider = nil;
    
    self.accessoryType = UITableViewCellAccessoryNone;
    self.editingAccessoryType = UITableViewCellAccessoryNone;
}

- (void)setKey:(NSString*)key value:(NSString*)value editing:(BOOL)editing {
    [self setKey:key value:value editing:editing keyColor:nil];
}

- (void)setKey:(NSString*)key value:(NSString*)value editing:(BOOL)editing suggestionProvider:(SuggestionProvider)suggestionProvider {
    [self setKey:key value:value editing:editing selectAllOnEdit:NO keyColor:nil formatAsUrl:NO suggestionProvider:suggestionProvider];
}

- (void)setKey:(NSString *)key value:(NSString *)value editing:(BOOL)editing keyColor:(UIColor *)keyColor {
    [self setKey:key value:value editing:editing selectAllOnEdit:NO keyColor:keyColor formatAsUrl:NO];
}

- (void)setKey:(NSString *)key value:(NSString *)value editing:(BOOL)editing selectAllOnEdit:(BOOL)selectAllOnEdit {
    [self setKey:key value:value editing:editing selectAllOnEdit:selectAllOnEdit keyColor:nil formatAsUrl:NO];
}

- (void)setKey:(NSString *)key value:(NSString *)value editing:(BOOL)editing formatAsUrl:(BOOL)formatAsUrl suggestionProvider:(SuggestionProvider)suggestionProvider {
    [self setKey:key value:value editing:editing selectAllOnEdit:NO keyColor:nil formatAsUrl:formatAsUrl suggestionProvider:suggestionProvider];
}

- (void)setKey:(NSString*)key
         value:(NSString*)value
       editing:(BOOL)editing
selectAllOnEdit:(BOOL)selectAllOnEdit
      keyColor:(UIColor *)keyColor
   formatAsUrl:(BOOL)formatAsUrl {
    [self setKey:key value:value editing:editing selectAllOnEdit:selectAllOnEdit keyColor:keyColor formatAsUrl:formatAsUrl suggestionProvider:nil];
}

- (void)setKey:(NSString*)key
         value:(NSString*)value
       editing:(BOOL)editing
selectAllOnEdit:(BOOL)selectAllOnEdit
      keyColor:(UIColor *)keyColor
   formatAsUrl:(BOOL)formatAsUrl
suggestionProvider:(SuggestionProvider)suggestionProvider {
    self.keyLabel.text = key;
    self.keyLabel.textColor = keyColor == nil ? UIColor.darkGrayColor : keyColor;

    self.valueText.text = value;
    self.valueText.enabled = editing;
    self.valueText.suggestionProvider = suggestionProvider;
    
    self.valueText.textColor = formatAsUrl ? UIColor.blueColor : UIColor.darkTextColor;
    self.rightAccessoryButton.hidden = !formatAsUrl || editing;
    
    self.selectAllOnEdit = selectAllOnEdit;
    
    self.horizontalLine.hidden = !editing;
    self.selectionStyle = editing ? UITableViewCellSelectionStyleNone : UITableViewCellSelectionStyleDefault;
}

- (BOOL)canBecomeFirstResponder {
    return YES;
}

- (BOOL)becomeFirstResponder {
    BOOL ret = [self.valueText becomeFirstResponder];
    
    if(self.selectAllOnEdit) {
        [self.valueText selectAll:nil];
    }
    
    return ret;
}

- (void)onValueEdited {
    if(self.onEdited) {
        self.onEdited(self.valueText.text);
    }
    
    if(self.showUiValidationOnEmpty) {
        if(self.valueText.text.length == 0) {
            self.horizontalLine.backgroundColor = UIColor.redColor;
            self.valueText.placeholder = [NSString stringWithFormat:@"%@ (Required)", self.keyLabel.text];
        }
        else {
            self.horizontalLine.backgroundColor = UIColor.blueColor;
        }
    }
}

- (IBAction)onRightAccessoryButton:(id)sender {
    if(self.onRightAccessoryButton) {
        self.onRightAccessoryButton();
    }
}

@end
