//
//  GenericKeyValueTableViewCell.m
//  test-new-ui
//
//  Created by Mark on 18/04/2019.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import "GenericKeyValueTableViewCell.h"
#import "FontManager.h"
#import "ItemDetailsViewController.h"
#import "ColoredStringHelper.h"
#import "AppPreferences.h"
#import "PasswordStrengthTester.h"
#import "PasswordStrengthUIHelper.h"
#import "ContextMenuHelper.h"

@interface GenericKeyValueTableViewCell ()

@property (weak, nonatomic) IBOutlet UIView *horizontalLine;
@property (weak, nonatomic) IBOutlet UILabel *keyLabel;
@property (weak, nonatomic) IBOutlet AutoCompleteTextField *valueText; 
@property (weak, nonatomic) IBOutlet UILabel *valueLabel; 
@property (weak, nonatomic) IBOutlet UIButton *buttonRightButton;

@property (weak, nonatomic) IBOutlet UIStackView *auditStack;
@property (weak, nonatomic) IBOutlet UIImageView *imageAuditError;
@property (weak, nonatomic) IBOutlet UILabel *labelAudit;

@property (weak, nonatomic) IBOutlet UIStackView *linesStack;

@property BOOL selectAllOnEdit;
@property BOOL useEasyReadFont;
@property BOOL concealed;

@property NSString* value;
@property BOOL colorizeValue;

@property UIImage* rightButtonImage;
@property (weak, nonatomic) IBOutlet UILabel *rightButtonSplashLabel;
@property UITapGestureRecognizer *rightButtonTap;
@property (weak, nonatomic) IBOutlet UIStackView *stackStrength;
@property (weak, nonatomic) IBOutlet UIProgressView *progressStrength;
@property (weak, nonatomic) IBOutlet UILabel *labelStrength;

@property (weak, nonatomic) IBOutlet UIButton *buttonHistory;
@property (weak, nonatomic) IBOutlet UIButton *buttonLargeTextView;

@property (weak, nonatomic) IBOutlet UIStackView *stackAssociatedWebsites;
@property (weak, nonatomic) IBOutlet UILabel *labelAssociatedWebsites;

@end

@implementation GenericKeyValueTableViewCell

- (void)awakeFromNib {
    [super awakeFromNib];

    self.horizontalLine.backgroundColor = UIColor.secondaryLabelColor;
    self.selectionStyle = UITableViewCellSelectionStyleDefault;
    
    self.keyLabel.font = FontManager.sharedInstance.caption1Font;
    
    self.valueText.onEdited = ^(NSString * _Nonnull text) {
        [self onValueEdited];
    };
    self.valueText.font = self.configuredValueFont;

    
    self.auditStack.hidden = YES;
    [self.linesStack setCustomSpacing:10.0f afterView:self.valueLabel];   
    
    self.keyLabel.adjustsFontForContentSizeCategory = YES;
    self.valueText.adjustsFontForContentSizeCategory = YES;
    self.valueLabel.adjustsFontForContentSizeCategory = YES;

    self.selectAllOnEdit = NO;
    






    self.rightButtonTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(onRightButton:)];
    [self.rightButtonTap setNumberOfTapsRequired:1];
    [self.rightButtonTap setNumberOfTouchesRequired:1];
    [self.rightButtonSplashLabel addGestureRecognizer:self.rightButtonTap];
    self.rightButtonSplashLabel.text = @" "; 

    
    
    self.buttonHistory.showsMenuAsPrimaryAction = YES;
    self.buttonHistory.hidden = YES;
    self.contentView.userInteractionEnabled = YES;
    
    
    
    self.labelAudit.userInteractionEnabled = YES;
    UITapGestureRecognizer *tapGesture =
          [[UITapGestureRecognizer alloc] initWithTarget:self
                                                  action:@selector(onAuditLabelTap)];
    [self.labelAudit addGestureRecognizer:tapGesture];

    UIImage* auditImage = [UIImage systemImageNamed:@"checkmark.shield"];
    
    self.imageAuditError.image = auditImage;
    self.imageAuditError.userInteractionEnabled = YES;
    UITapGestureRecognizer *imageAuditErrorGesture =
          [[UITapGestureRecognizer alloc] initWithTarget:self
                                                  action:@selector(onAuditLabelTap)];
    [self.imageAuditError addGestureRecognizer:imageAuditErrorGesture];
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
    
    self.horizontalLine.backgroundColor = UIColor.secondaryLabelColor;

    self.onEdited = nil;
    self.showUiValidationOnEmpty = NO;
    self.suggestionProvider = nil;
    
    self.accessoryType = UITableViewCellAccessoryNone;
    self.editingAccessoryType = UITableViewCellAccessoryNone;
    self.selectionStyle = UITableViewCellSelectionStyleDefault;
    
    self.buttonRightButton.hidden = YES;
    
    self.rightButtonImage = nil;
    self.onRightButton = nil;

    self.auditStack.hidden = YES;
    self.stackStrength.hidden = YES;
    
    [self.buttonRightButton setPreferredSymbolConfiguration:[UIImageSymbolConfiguration configurationWithScale:UIImageSymbolScaleLarge]
                                                forImageInState:UIControlStateNormal];
    
    self.historyMenu = nil;
}

- (void)setKey:(NSString*)key value:(NSString*)value editing:(BOOL)editing useEasyReadFont:(BOOL)useEasyReadFont {
    [self setKey:key value:value editing:editing useEasyReadFont:useEasyReadFont rightButtonImage:nil suggestionProvider:nil];
}

- (void)setKey:(NSString *)key value:(NSString *)value editing:(BOOL)editing useEasyReadFont:(BOOL)useEasyReadFont rightButtonImage:(UIImage *)rightButtonImage suggestionProvider:(SuggestionProvider)suggestionProvider {
    [self setKey:key value:value editing:editing useEasyReadFont:useEasyReadFont formatAsUrl:NO rightButtonImage:rightButtonImage suggestionProvider:suggestionProvider];
}

- (void)setKey:(NSString *)key value:(NSString *)value editing:(BOOL)editing useEasyReadFont:(BOOL)useEasyReadFont formatAsUrl:(BOOL)formatAsUrl rightButtonImage:(UIImage *)rightButtonImage suggestionProvider:(SuggestionProvider)suggestionProvider {
    [self setKey:key value:value editing:editing selectAllOnEdit:NO formatAsUrl:formatAsUrl suggestionProvider:suggestionProvider useEasyReadFont:useEasyReadFont rightButtonImage:rightButtonImage concealed:NO colorizeValue:NO];
}

- (void)setKey:(NSString*)key value:(NSString*)value editing:(BOOL)editing selectAllOnEdit:(BOOL)selectAllOnEdit formatAsUrl:(BOOL)formatAsUrl useEasyReadFont:(BOOL)useEasyReadFont {
    [self setKey:key
           value:value
         editing:editing
 selectAllOnEdit:selectAllOnEdit
     formatAsUrl:formatAsUrl
suggestionProvider:nil
 useEasyReadFont:useEasyReadFont
rightButtonImage:nil
       concealed:NO
   colorizeValue:NO];
}



- (void)setForUrlOrCustomFieldUrl:(NSString*)key
                            value:(NSString*)value
                      formatAsUrl:(BOOL)formatAsUrl
                 rightButtonImage:(UIImage*)rightButtonImage
                  useEasyReadFont:(BOOL)useEasyReadFont
               associatedWebsites:(NSArray<NSString*>*)associatedWebsites {
    [self setKey:key
           value:value
         editing:NO
 selectAllOnEdit:NO
     formatAsUrl:formatAsUrl
suggestionProvider:nil
 useEasyReadFont:useEasyReadFont
rightButtonImage:rightButtonImage
       concealed:NO
   colorizeValue:NO
           audit:nil
    showStrength:NO
associatedWebsites:associatedWebsites
showLargeTextView:NO];
}

- (void)setConcealableKey:(NSString *)key
                     value:(NSString *)value
                 concealed:(BOOL)concealed
                  colorize:(BOOL)colorize
                     audit:(NSString *)audit
             showStrength:(BOOL)showStrength {
    [self setConcealableKey:key value:value concealed:concealed colorize:colorize audit:audit showStrength:showStrength showLargeTextView:NO];
}

- (void)setConcealableKey:(NSString *)key 
                    value:(NSString *)value
                concealed:(BOOL)concealed
                 colorize:(BOOL)colorize
                    audit:(NSString *)audit
             showStrength:(BOOL)showStrength
        showLargeTextView:(BOOL)showLargeTextView {
    
        
    UIImage *image = [UIImage systemImageNamed:concealed ? @"eye" : @"eye.slash"];
  
    [self setKey:key
           value:value
         editing:NO
  selectAllOnEdit:NO
     formatAsUrl:NO
suggestionProvider:nil
 useEasyReadFont:YES
rightButtonImage:image
       concealed:concealed
   colorizeValue:colorize
           audit:audit
    showStrength:showStrength 
associatedWebsites:@[] 
showLargeTextView:showLargeTextView];
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
 colorizeValue:(BOOL)colorizeValue {
    [self setKey:key
           value:value
         editing:editing
 selectAllOnEdit:selectAllOnEdit
     formatAsUrl:formatAsUrl
suggestionProvider:suggestionProvider
 useEasyReadFont:useEasyReadFont
rightButtonImage:rightButtonImage
       concealed:concealed
   colorizeValue:colorizeValue
           audit:nil
    showStrength:NO
associatedWebsites:@[]
showLargeTextView:NO];
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
 colorizeValue:(BOOL)colorizeValue
         audit:(NSString*_Nullable)audit
  showStrength:(BOOL)showStrength
associatedWebsites:(NSArray<NSString*>*)associatedWebsites 
showLargeTextView:(BOOL)showLargeTextView {
    [self bindKey:key];
        
    self.selectAllOnEdit = selectAllOnEdit;
    
    self.horizontalLine.hidden = !editing;
    self.selectionStyle = editing ? UITableViewCellSelectionStyleNone : UITableViewCellSelectionStyleDefault;
    self.useEasyReadFont = useEasyReadFont;
    self.selectionStyle = UITableViewCellSelectionStyleDefault;
    
    self.rightButtonImage = rightButtonImage;
    
    self.concealed = concealed;
    self.colorizeValue = colorizeValue;
    
    self.value = value;
    [self bindValue:formatAsUrl suggestionProvider:suggestionProvider editing:editing key:key];
    
    self.valueLabel.hidden = self.editing;
    self.valueText.hidden = !self.editing;
    
    [self bindAudit:audit];
    [self bindRightButton];
    [self bindStrength:showStrength];
    
    self.buttonLargeTextView.hidden = !showLargeTextView;
    
    [self bindAssociatedWebsites:associatedWebsites];
}

- (void)bindAssociatedWebsites:(NSArray<NSString*>*)associatedWebsites {
    self.stackAssociatedWebsites.hidden = associatedWebsites.count == 0;
    
    NSString* sites = [associatedWebsites componentsJoinedByString:@", "];
    self.labelAssociatedWebsites.text = sites;
}

- (void)setOnRightButton:(void (^)(void))onRightButton {
    _onRightButton = onRightButton;
    [self bindRightButton];
}

- (void)bindAudit:(NSString*)audit {
    self.auditStack.hidden = audit.length == 0;
    self.labelAudit.text = audit ? audit : @"";
}

- (void)bindKey:(NSString*)key {
    self.keyLabel.text = key;
    self.keyLabel.textColor = UIColor.secondaryLabelColor;
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
        self.valueText.textColor = UIColor.linkColor;
        self.valueLabel.textColor = UIColor.linkColor;
    }
}

- (void)bindValueText {
    if(self.concealed) {
        
        self.valueText.text = NSLocalizedString(@"generic_masked_protected_field_text", @"*****************");
        self.valueLabel.text = NSLocalizedString(@"generic_masked_protected_field_text", @"*****************");

        self.valueText.textColor = UIColor.secondaryLabelColor;
        self.valueLabel.textColor = UIColor.secondaryLabelColor;

        self.valueText.font = FontManager.sharedInstance.caption1Font;
        self.valueLabel.font = FontManager.sharedInstance.caption1Font;
    }
    else {
        self.valueText.accessibilityLabel = nil;
        self.valueLabel.accessibilityLabel = nil;
        
        if (self.colorizeValue) {
            BOOL dark = self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark;
            BOOL colorBlind = AppPreferences.sharedInstance.colorizeUseColorBlindPalette;
            
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
            self.valueText.textColor = UIColor.labelColor;
            self.valueLabel.textColor = UIColor.labelColor;
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
            self.horizontalLine.backgroundColor = UIColor.secondaryLabelColor;
        }
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
    
    UIImage *image = [UIImage systemImageNamed:self.concealed ? @"eye" : @"eye.slash"];
    self.rightButtonImage = image;

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
    if(self.onRightButton) {
        self.onRightButton();
    }
}

- (void)bindRightButton {
    if(self.rightButtonImage) {
        self.buttonRightButton.hidden = NO;
        self.rightButtonSplashLabel.hidden = NO;
        [self.buttonRightButton setImage:self.rightButtonImage forState:UIControlStateNormal];
    }
    else {
        self.buttonRightButton.hidden = YES;
        self.rightButtonSplashLabel.hidden = YES;
        [self.buttonRightButton setImage:nil forState:UIControlStateNormal];
    }

    self.rightButtonTap.enabled = self.onRightButton != nil;
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

- (void)bindStrength:(BOOL)showStrength {
    if ( showStrength && self.value.length ) {
        [PasswordStrengthUIHelper bindStrengthUI:self.value
                                          config:AppPreferences.sharedInstance.passwordStrengthConfig
                              emptyPwHideSummary:NO
                                           label:self.labelStrength
                                        progress:self.progressStrength];
        
        self.stackStrength.hidden = NO;
    }
    else {
        self.stackStrength.hidden = YES;
    }
}

- (UIMenu *)historyMenu {
    return self.buttonHistory.menu;
}

- (void)setHistoryMenu:(UIMenu *)historyMenu {
    self.buttonHistory.menu = historyMenu;
    self.buttonHistory.hidden = historyMenu == nil;
}

- (IBAction)onShowLargeTextView:(id)sender {
    if ( self.onShowLargeTextView ) {
        self.onShowLargeTextView();
    }
}

@end
