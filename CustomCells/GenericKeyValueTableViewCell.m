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

@property BOOL selectAllOnEdit;
@property BOOL useEasyReadFont;

@end

@implementation GenericKeyValueTableViewCell

- (void)awakeFromNib {
    [super awakeFromNib];

    self.horizontalLine.backgroundColor = UIColor.blueColor;
    self.selectionStyle = UITableViewCellSelectionStyleDefault;
    
    self.keyLabel.font = FontManager.sharedInstance.regularFont;
    self.keyLabel.adjustsFontForContentSizeCategory = YES;
    
    self.valueText.adjustsFontForContentSizeCategory = YES;
    self.valueText.onEdited = ^(NSString * _Nonnull text) {
        [self onValueEdited];
    };
    self.valueText.font = self.configuredValueFont;

    self.selectAllOnEdit = NO;
    
    UITapGestureRecognizer *doubleTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(onDoubleTap:)];
    [doubleTap setNumberOfTapsRequired:2];
    [doubleTap setNumberOfTouchesRequired:1];
    [self addGestureRecognizer:doubleTap];

    UITapGestureRecognizer *singleTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(onTap:)];
    [singleTap setNumberOfTapsRequired:1];
    [singleTap setNumberOfTouchesRequired:1];
    [self addGestureRecognizer:singleTap];
    
    [singleTap requireGestureRecognizerToFail:doubleTap];
}

- (void)prepareForReuse {
    [super prepareForReuse];

    self.selectAllOnEdit = NO;
    
    self.keyLabel.text = @"";
    self.valueText.text = @"";
    self.valueText.tag = 0;
    self.valueText.enabled = NO;
    self.valueText.placeholder = @"";
    self.valueText.font = self.configuredValueFont;
    
    self.horizontalLine.backgroundColor = UIColor.blueColor;
    
    self.onEdited = nil;
    self.showUiValidationOnEmpty = NO;
    self.suggestionProvider = nil;
    
    self.accessoryType = UITableViewCellAccessoryNone;
    self.editingAccessoryType = UITableViewCellAccessoryNone;
    self.selectionStyle = UITableViewCellSelectionStyleDefault;
}

- (void)setKey:(NSString*)key value:(NSString*)value editing:(BOOL)editing useEasyReadFont:(BOOL)useEasyReadFont {
    [self setKey:key value:value editing:editing keyColor:nil useEasyReadFont:useEasyReadFont];
}

- (void)setKey:(NSString*)key value:(NSString*)value editing:(BOOL)editing suggestionProvider:(SuggestionProvider)suggestionProvider useEasyReadFont:(BOOL)useEasyReadFont {
    [self setKey:key value:value editing:editing selectAllOnEdit:NO keyColor:nil formatAsUrl:NO suggestionProvider:suggestionProvider useEasyReadFont:useEasyReadFont];
}

- (void)setKey:(NSString *)key value:(NSString *)value editing:(BOOL)editing keyColor:(UIColor *)keyColor useEasyReadFont:(BOOL)useEasyReadFont {
    [self setKey:key value:value editing:editing selectAllOnEdit:NO keyColor:keyColor formatAsUrl:NO useEasyReadFont:useEasyReadFont];
}

- (void)setKey:(NSString *)key value:(NSString *)value editing:(BOOL)editing selectAllOnEdit:(BOOL)selectAllOnEdit useEasyReadFont:(BOOL)useEasyReadFont {
    [self setKey:key value:value editing:editing selectAllOnEdit:selectAllOnEdit keyColor:nil formatAsUrl:NO useEasyReadFont:useEasyReadFont];
}

- (void)setKey:(NSString *)key value:(NSString *)value editing:(BOOL)editing formatAsUrl:(BOOL)formatAsUrl suggestionProvider:(SuggestionProvider)suggestionProvider useEasyReadFont:(BOOL)useEasyReadFont {
    [self setKey:key value:value editing:editing selectAllOnEdit:NO keyColor:nil formatAsUrl:formatAsUrl suggestionProvider:suggestionProvider useEasyReadFont:useEasyReadFont];
}

- (void)setKey:(NSString*)key
         value:(NSString*)value
       editing:(BOOL)editing
selectAllOnEdit:(BOOL)selectAllOnEdit
      keyColor:(UIColor *)keyColor
   formatAsUrl:(BOOL)formatAsUrl useEasyReadFont:(BOOL)useEasyReadFont {
    [self setKey:key value:value editing:editing selectAllOnEdit:selectAllOnEdit keyColor:keyColor formatAsUrl:formatAsUrl suggestionProvider:nil useEasyReadFont:useEasyReadFont];
}

- (void)setKey:(NSString*)key
         value:(NSString*)value
       editing:(BOOL)editing
selectAllOnEdit:(BOOL)selectAllOnEdit
      keyColor:(UIColor *)keyColor
   formatAsUrl:(BOOL)formatAsUrl
suggestionProvider:(SuggestionProvider)suggestionProvider useEasyReadFont:(BOOL)useEasyReadFont {
    self.keyLabel.text = key;
    self.keyLabel.textColor = keyColor == nil ? UIColor.darkGrayColor : keyColor;
    self.keyLabel.accessibilityLabel = key;
    
    self.valueText.text = value;
    self.valueText.enabled = editing;
    self.valueText.suggestionProvider = suggestionProvider;
    self.valueText.accessibilityLabel = [key stringByAppendingString:NSLocalizedString(@"generic_kv_cell_value_text_accessibility label_fmt", @" Text Field")];
    
    self.valueText.textColor = formatAsUrl ? UIColor.blueColor : UIColor.darkTextColor;
    
    self.selectAllOnEdit = selectAllOnEdit;
    
    self.horizontalLine.hidden = !editing;
    self.selectionStyle = editing ? UITableViewCellSelectionStyleNone : UITableViewCellSelectionStyleDefault;
    self.useEasyReadFont = useEasyReadFont;
    self.valueText.font = self.configuredValueFont;
    self.selectionStyle = UITableViewCellSelectionStyleDefault;
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
            self.valueText.placeholder = [NSString stringWithFormat:NSLocalizedString(@"generic_kv_cell_value_empty_value_validation_fmt", @"%@ (Required)"), self.keyLabel.text];
        }
        else {
            self.horizontalLine.backgroundColor = UIColor.blueColor;
        }
    }
}

- (void)onTap:(id)sender {
    if(self.onTap && !self.isEditing) {
        self.onTap();
    }
}

- (void)onDoubleTap:(id)sender {
    if(self.onDoubleTap && !self.isEditing) {
        self.onDoubleTap();
    }
}

- (UIFont*)configuredValueFont {
    return self.useEasyReadFont ? FontManager.sharedInstance.easyReadFont : FontManager.sharedInstance.regularFont;
}

@end
