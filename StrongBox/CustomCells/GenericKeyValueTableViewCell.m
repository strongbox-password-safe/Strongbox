//
//  GenericKeyValueTableViewCell.m
//  test-new-ui
//
//  Created by Mark on 18/04/2019.
//  Copyright © 2019 Mark McGuill. All rights reserved.
//

#import "GenericKeyValueTableViewCell.h"
#import "FontManager.h"
#import "ItemDetailsViewController.h"
#import "ColoredStringHelper.h"
#import "SharedAppAndAutoFillSettings.h"

@interface GenericKeyValueTableViewCell ()

@property (weak, nonatomic) IBOutlet UIView *horizontalLine;
@property (weak, nonatomic) IBOutlet UILabel *keyLabel;
@property (weak, nonatomic) IBOutlet AutoCompleteTextField *valueText; // allows for inline editing
@property (weak, nonatomic) IBOutlet UILabel *valueLabel; // Allows for multiline display in non edit mode
@property (weak, nonatomic) IBOutlet UIButton *buttonRightButton;

@property (weak, nonatomic) IBOutlet UIStackView *auditStack;
@property (weak, nonatomic) IBOutlet UIImageView *imageAuditError;
@property (weak, nonatomic) IBOutlet UILabel *labelAudit;

@property (weak, nonatomic) IBOutlet UIStackView *linesStack;

@property BOOL selectAllOnEdit;
@property BOOL useEasyReadFont;
@property BOOL concealed;

@property NSString* value;
@property UIImage* rightButtonImage;
@property BOOL showGenerateButton;
@property BOOL colorizeValue;

@property (weak, nonatomic) IBOutlet UIView *rightButtonView;

@end

@implementation GenericKeyValueTableViewCell

- (void)awakeFromNib {
    [super awakeFromNib];

    self.imageAuditError.image = [UIImage imageNamed:@"security_checked"];

    if (@available(iOS 13.0, *)) {
        self.horizontalLine.backgroundColor = UIColor.secondaryLabelColor;
    }
    else {
        self.horizontalLine.backgroundColor = UIColor.darkGrayColor;
    }
    self.selectionStyle = UITableViewCellSelectionStyleDefault;
    
    self.keyLabel.font = FontManager.sharedInstance.caption1Font;
    self.keyLabel.adjustsFontForContentSizeCategory = YES;
    
    self.valueText.adjustsFontForContentSizeCategory = YES;
    self.valueText.onEdited = ^(NSString * _Nonnull text) {
        [self onValueEdited];
    };
    self.valueText.font = self.configuredValueFont;

    self.valueLabel.adjustsFontForContentSizeCategory = YES;
    
    self.auditStack.hidden = YES;
    if (@available(iOS 11.0, *)) {
        [self.linesStack setCustomSpacing:10.0f afterView:self.valueLabel];
    }
    
    self.selectAllOnEdit = NO;
    
    UITapGestureRecognizer *doubleTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(onDoubleTap:)];
    [doubleTap setNumberOfTapsRequired:2];
    [doubleTap setNumberOfTouchesRequired:1];
    doubleTap.delaysTouchesBegan = YES; // Required so that didSelectRowAtIndex is not called!
    [self addGestureRecognizer:doubleTap];

    UITapGestureRecognizer *singleTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(onTap:)];
    [singleTap setNumberOfTapsRequired:1];
    [singleTap setNumberOfTouchesRequired:1];
    singleTap.delaysTouchesBegan = YES; // Required so that didSelectRowAtIndex is not called!
    [self addGestureRecognizer:singleTap];

    [singleTap requireGestureRecognizerToFail:doubleTap];

    self.labelAudit.userInteractionEnabled = YES;
    UITapGestureRecognizer *tapGesture =
          [[UITapGestureRecognizer alloc] initWithTarget:self
                                                  action:@selector(onAuditLabelTap)];
    [self.labelAudit addGestureRecognizer:tapGesture];
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
    
    self.valueLabel.text = @"";
    
    self.valueLabel.hidden = YES;
    self.valueText.hidden = NO;
    
    if (@available(iOS 13.0, *)) {
        self.horizontalLine.backgroundColor = UIColor.secondaryLabelColor;
    } else {
        self.horizontalLine.backgroundColor = UIColor.darkGrayColor;
    }

    self.onEdited = nil;
    self.showUiValidationOnEmpty = NO;
    self.suggestionProvider = nil;
    
    self.onTap = nil;
    self.onDoubleTap = nil;
    
    self.accessoryType = UITableViewCellAccessoryNone;
    self.editingAccessoryType = UITableViewCellAccessoryNone;
    self.selectionStyle = UITableViewCellSelectionStyleDefault;
    
    self.buttonRightButton.hidden = YES;
    
    self.rightButtonImage = nil;
    self.showGenerateButton = NO;

    self.auditStack.hidden = YES;
}

- (void)setKey:(NSString*)key value:(NSString*)value editing:(BOOL)editing useEasyReadFont:(BOOL)useEasyReadFont {
    [self setKey:key value:value editing:editing suggestionProvider:nil useEasyReadFont:useEasyReadFont showGenerateButton:NO];
}

- (void)setKey:(NSString*)key value:(NSString*)value editing:(BOOL)editing suggestionProvider:(SuggestionProvider)suggestionProvider useEasyReadFont:(BOOL)useEasyReadFont showGenerateButton:(BOOL)showGenerateButton {
    [self setKey:key value:value editing:editing selectAllOnEdit:NO formatAsUrl:NO suggestionProvider:suggestionProvider useEasyReadFont:useEasyReadFont rightButtonImage:nil concealed:NO showGenerateButton:showGenerateButton colorizeValue:NO];
}


- (void)setKey:(NSString *)key value:(NSString *)value editing:(BOOL)editing selectAllOnEdit:(BOOL)selectAllOnEdit useEasyReadFont:(BOOL)useEasyReadFont {
    [self setKey:key value:value editing:editing selectAllOnEdit:selectAllOnEdit formatAsUrl:NO useEasyReadFont:useEasyReadFont];
}

- (void)setKey:(NSString *)key value:(NSString *)value editing:(BOOL)editing formatAsUrl:(BOOL)formatAsUrl suggestionProvider:(SuggestionProvider)suggestionProvider useEasyReadFont:(BOOL)useEasyReadFont {
    [self setKey:key value:value editing:editing selectAllOnEdit:NO formatAsUrl:formatAsUrl suggestionProvider:suggestionProvider useEasyReadFont:useEasyReadFont rightButtonImage:nil concealed:NO showGenerateButton:NO colorizeValue:NO];
}

- (void)setKey:(NSString*)key
         value:(NSString*)value
       editing:(BOOL)editing
selectAllOnEdit:(BOOL)selectAllOnEdit
   formatAsUrl:(BOOL)formatAsUrl
useEasyReadFont:(BOOL)useEasyReadFont {
    [self setKey:key
           value:value
         editing:editing
 selectAllOnEdit:selectAllOnEdit
     formatAsUrl:formatAsUrl
suggestionProvider:nil
 useEasyReadFont:useEasyReadFont
rightButtonImage:nil
       concealed:NO
showGenerateButton:NO colorizeValue:NO];
}

- (void)setConfidentialKey:(NSString *)key
                     value:(NSString *)value
                 concealed:(BOOL)concealed
                  colorize:(BOOL)colorize
                     audit:(NSString *)audit {
    // Only for viewing - special cells required for edit...
        
    UIImage* image = [UIImage imageNamed:concealed ? @"visible" : @"invisible"];

    [self setKey:key
            value:value
          editing:NO
  selectAllOnEdit:NO
      formatAsUrl:NO
suggestionProvider:nil
 useEasyReadFont:YES
 rightButtonImage:image
        concealed:concealed
showGenerateButton:NO
   colorizeValue:colorize
           audit:audit];
}

- (void)setKey:(NSString*)key
         value:(NSString*)value
       editing:(BOOL)editing
    selectAllOnEdit:(BOOL)selectAllOnEdit
    formatAsUrl:(BOOL)formatAsUrl
    suggestionProvider:(SuggestionProvider)suggestionProvider
    useEasyReadFont:(BOOL)useEasyReadFont
 rightButtonImage:(UIImage*)rightButtonImage
     concealed:(BOOL)concealed
showGenerateButton:(BOOL)showGenerateButton
 colorizeValue:(BOOL)colorizeValue {
    [self setKey:key value:value
         editing:editing
 selectAllOnEdit:selectAllOnEdit
     formatAsUrl:formatAsUrl
suggestionProvider:suggestionProvider
 useEasyReadFont:useEasyReadFont
rightButtonImage:rightButtonImage
       concealed:concealed
showGenerateButton:showGenerateButton
   colorizeValue:colorizeValue
           audit:nil];
}

- (void)setKey:(NSString*)key
         value:(NSString*)value
       editing:(BOOL)editing
    selectAllOnEdit:(BOOL)selectAllOnEdit
    formatAsUrl:(BOOL)formatAsUrl
    suggestionProvider:(SuggestionProvider)suggestionProvider
    useEasyReadFont:(BOOL)useEasyReadFont
 rightButtonImage:(UIImage*)rightButtonImage
     concealed:(BOOL)concealed
showGenerateButton:(BOOL)showGenerateButton
 colorizeValue:(BOOL)colorizeValue
         audit:(NSString*_Nullable)audit {
    [self bindKey:key];
        
    self.selectAllOnEdit = selectAllOnEdit;
    
    self.horizontalLine.hidden = !editing;
    self.selectionStyle = editing ? UITableViewCellSelectionStyleNone : UITableViewCellSelectionStyleDefault;
    self.useEasyReadFont = useEasyReadFont;
    self.selectionStyle = UITableViewCellSelectionStyleDefault;
    
    self.rightButtonImage = rightButtonImage;
    self.showGenerateButton = showGenerateButton;
    
    [self bindRightButton];

    self.concealed = concealed;
    self.colorizeValue = colorizeValue;
    
    self.value = value;
    [self bindValue:formatAsUrl suggestionProvider:suggestionProvider editing:editing key:key];
    
    self.valueLabel.hidden = self.editing;
    self.valueText.hidden = !self.editing;
    
    [self bindAudit:audit];
}

- (void)bindAudit:(NSString*)audit {
    self.auditStack.hidden = audit.length == 0;
    self.labelAudit.text = audit ? audit : @"";
}

- (void)bindKey:(NSString*)key {
    self.keyLabel.text = key;
    if (@available(iOS 13.0, *)) {
        self.keyLabel.textColor = UIColor.secondaryLabelColor;
    }
    else {
        self.keyLabel.textColor = nil;
    }
    self.keyLabel.accessibilityLabel = key;
}

- (void)bindValue:(BOOL)formatAsUrl
suggestionProvider:(SuggestionProvider)suggestionProvider
          editing:(BOOL)editing
              key:(NSString*)key {
    self.valueText.enabled = editing;
    self.valueText.suggestionProvider = suggestionProvider;

    self.valueText.accessibilityLabel = [key stringByAppendingString:NSLocalizedString(@"generic_kv_cell_value_text_accessibility label_fmt", @" Text Field")];
    self.valueLabel.accessibilityLabel = [key stringByAppendingString:NSLocalizedString(@"generic_kv_cell_value_text_accessibility label_fmt", @" Text Field")];

    [self bindValueText];

    if(formatAsUrl) {
        if (@available(iOS 13.0, *)) {
            self.valueText.textColor = UIColor.linkColor;
            self.valueLabel.textColor = UIColor.linkColor;
        } else {
            self.valueText.textColor = UIColor.blueColor;
            self.valueLabel.textColor = UIColor.blueColor;
        }
    }
}

- (void)bindValueText {
    if(self.concealed) {
        
        self.valueText.text = NSLocalizedString(@"generic_masked_protected_field_text", @"*****************");
        self.valueLabel.text = NSLocalizedString(@"generic_masked_protected_field_text", @"*****************");

        if (@available(iOS 13.0, *)) {
            self.valueText.textColor = UIColor.secondaryLabelColor;
            self.valueLabel.textColor = UIColor.secondaryLabelColor;
        }
        else {
            self.valueText.textColor = UIColor.darkGrayColor;
            self.valueLabel.textColor = UIColor.darkGrayColor;
        }

        self.valueText.font = FontManager.sharedInstance.caption1Font;
        self.valueLabel.font = FontManager.sharedInstance.caption1Font;
    }
    else {
        self.valueText.accessibilityLabel = nil;
        self.valueLabel.accessibilityLabel = nil;
        
        if (self.colorizeValue) {
            BOOL dark = NO;
            if (@available(iOS 12.0, *)) {
                dark = self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark;
            }
            BOOL colorBlind = SharedAppAndAutoFillSettings.sharedInstance.colorizeUseColorBlindPalette;
            
            self.valueText.attributedText = [ColoredStringHelper getColorizedAttributedString:self.value
                                                                                     colorize:self.colorizeValue
                                                                                     darkMode:dark
                                                                                   colorBlind:colorBlind
                                                                                         font:self.configuredValueFont];
            
            self.valueLabel.attributedText = [ColoredStringHelper getColorizedAttributedString:self.value
                                                                                      colorize:self.colorizeValue
                                                                                      darkMode:dark
                                                                                    colorBlind:colorBlind
                                                                                          font:self.configuredValueFont];
        }
        else {
            self.valueText.text = self.value;
            self.valueLabel.text = self.value;
            self.valueText.font = self.configuredValueFont;
            self.valueLabel.font = self.configuredValueFont;
            
            if (@available(iOS 13.0, *)) {
                self.valueText.textColor = UIColor.labelColor;
                self.valueLabel.textColor = UIColor.labelColor;
            }
            else {
                self.valueText.textColor = UIColor.darkTextColor;
                self.valueLabel.textColor = UIColor.darkTextColor;
            }
        }
    }
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
            self.horizontalLine.backgroundColor = UIColor.systemRedColor;
            self.valueText.placeholder = [NSString stringWithFormat:NSLocalizedString(@"generic_kv_cell_value_empty_value_validation_fmt", @"%@ (Required)"), self.keyLabel.text];
        }
        else {
            if (@available(iOS 13.0, *)) {
                self.horizontalLine.backgroundColor = UIColor.secondaryLabelColor;
            }
            else {
                self.horizontalLine.backgroundColor = UIColor.darkGrayColor;
            }
        }
    }
}

- (void)onTap:(id)sender {
    UITapGestureRecognizer* rec = (UITapGestureRecognizer*)sender;
    CGPoint pnt = [rec locationInView:self.rightButtonView];
    BOOL inRect = CGRectContainsPoint(self.rightButtonView.bounds, pnt);
    
    if (inRect && self.onRightButton) {
        NSLog(@"XXXX - Splashy Right Button Tap!");
        [self onRightButton:sender];
    }
    else {
        if(self.onTap) {
            self.onTap();
        }
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

- (BOOL)isConcealed {
    return self.concealed;
}

- (void)setIsConcealed:(BOOL)isConcealed {
    self.concealed = isConcealed;
    
    self.rightButtonImage = [UIImage imageNamed:self.concealed ? @"visible" : @"invisible"];

    [self bindRightButton];
    [self bindValueText];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:CellHeightsChangedNotification object:self];
}

- (void)setEditing:(BOOL)editing animated:(BOOL)animated {
    [super setEditing:editing animated:animated];
   
    self.valueLabel.hidden = self.editing;
    self.valueText.hidden = !self.editing;
    
    [self bindRightButton];
}

- (IBAction)onRightButton:(id)sender {
    if(self.editing) {
        if(self.onGenerate) {
            self.onGenerate();
        }
    }
    else {
        if(self.onRightButton) {
            self.onRightButton();
        }
    }
}

- (void)bindRightButton {
    if(!self.editing) {
        if(self.rightButtonImage) {
            self.buttonRightButton.hidden = NO;
            [self.buttonRightButton setImage:self.rightButtonImage forState:UIControlStateNormal];
        }
        else {
            self.buttonRightButton.hidden = YES;
        }
    }
    else {
        if(self.showGenerateButton) {
            self.buttonRightButton.hidden = NO;
            [self.buttonRightButton setImage:[UIImage imageNamed:@"syncronize"] forState:UIControlStateNormal];
        }
    }
}

- (void)pokeValue:(NSString *)value {
    self.value = value;
    [self bindValueText];
    [self onValueEdited];
}

- (void)onAuditLabelTap {
    if (self.onAuditTap) {
        self.onAuditTap();
    }
}

@end
