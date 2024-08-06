//
//  EditPasswordTableViewCell.m
//  test-new-ui
//
//  Created by Mark on 22/04/2019.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import "EditPasswordTableViewCell.h"
#import "ItemDetailsViewController.h"
#import "MBAutoGrowingTextView.h"
#import "PasswordMaker.h"
#import "FontManager.h"
#import "ColoredStringHelper.h"
#import "AppPreferences.h"
#import "PasswordStrengthTester.h"
#import "PasswordStrengthUIHelper.h"
#import "TouchDownGestureRecognizer.h"

@interface EditPasswordTableViewCell () <UITextViewDelegate>

@property (weak, nonatomic) IBOutlet MBAutoGrowingTextView *valueTextView;
@property (weak, nonatomic) IBOutlet UIButton *buttonGenerationSettings;
@property BOOL internalShowGenerationSettings;
@property (weak, nonatomic) IBOutlet UILabel *labelStrength;
@property (weak, nonatomic) IBOutlet UIProgressView *progressStrength;
@property (weak, nonatomic) IBOutlet UIButton *buttonHistory;
@property (weak, nonatomic) IBOutlet UIButton *buttonGenerate;

@property BOOL isInShouldChangeMethod;

@property NSString* passwordBackingStore;
@property (weak, nonatomic) IBOutlet UIButton *buttonToggleConceal;
@property (weak, nonatomic) IBOutlet UIButton *buttonClearPassword;

@property TouchDownGestureRecognizer* touchDownGenerateButtonGestureRecognizer;



@property (weak, nonatomic) IBOutlet UIView *tipView;
@property UITapGestureRecognizer* closeTipGestureRecognizer;
@property (weak, nonatomic) IBOutlet UIStackView *stackViewTip;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *tipBottomConstraint;

@end

@implementation EditPasswordTableViewCell

- (void)awakeFromNib {
    [super awakeFromNib];
    
    self.concealPassword = YES;
    
    self.valueTextView.delegate = self;
    self.valueTextView.font = FontManager.sharedInstance.easyReadFont;
    
    self.valueTextView.adjustsFontForContentSizeCategory = YES;
    
    self.valueTextView.accessibilityLabel = NSLocalizedString(@"edit_password_cell_value_textfield_accessibility_label", @"Password Text Field");
    
    [self customizeIcons];
    
    [self refreshGeneratedMenu];
    
    
    
    self.touchDownGenerateButtonGestureRecognizer = [[TouchDownGestureRecognizer alloc] initWithTarget:self action:@selector(onButtonGenerateTouchedDown:)];
    self.touchDownGenerateButtonGestureRecognizer.cancelsTouchesInView = NO;
    [self.buttonGenerate addGestureRecognizer:self.touchDownGenerateButtonGestureRecognizer];
    
    
    
    self.buttonGenerationSettings.hidden = !self.showGenerationSettings;
    
    if ( AppPreferences.sharedInstance.hideTips ) {
        self.tipView.hidden = YES;
        self.tipBottomConstraint.constant = 8.0f;
    }
    else {
        self.tipView.layer.cornerRadius = 3.0f;
    }
    
    
    
    self.buttonHistory.showsMenuAsPrimaryAction = YES;
    self.buttonHistory.hidden = YES;
    
    
}

- (void)customizeIcons {
    [self.buttonClearPassword setImage:[UIImage systemImageNamed:@"xmark.circle"] forState:UIControlStateNormal];
    [self.buttonClearPassword setPreferredSymbolConfiguration:[UIImageSymbolConfiguration configurationWithScale:UIImageSymbolScaleLarge]
                                                   forImageInState:UIControlStateNormal];

    [self.buttonGenerationSettings setImage:[UIImage systemImageNamed:@"gear"] forState:UIControlStateNormal];

    [self.buttonGenerationSettings setPreferredSymbolConfiguration:[UIImageSymbolConfiguration configurationWithScale:UIImageSymbolScaleLarge]
                                                   forImageInState:UIControlStateNormal];
    
    [self.buttonGenerate setImage:[UIImage systemImageNamed:@"arrow.triangle.2.circlepath"] forState:UIControlStateNormal];

    [self.buttonGenerate setPreferredSymbolConfiguration:[UIImageSymbolConfiguration configurationWithScale:UIImageSymbolScaleLarge]
                                                       forImageInState:UIControlStateNormal];
}

- (void)onButtonGenerateTouchedDown:(UIGestureRecognizer*)gesture {
    [self refreshGeneratedMenu];
}

- (BOOL)showGenerationSettings {
    return self.internalShowGenerationSettings;
}

- (void)setShowGenerationSettings:(BOOL)showGenerationSettings {
    self.internalShowGenerationSettings = showGenerationSettings;

    self.buttonGenerationSettings.hidden = !self.internalShowGenerationSettings;
}

- (void)prepareForReuse {
    [super prepareForReuse];
    
    self.concealPassword = YES;
    
    self.buttonGenerationSettings.hidden = !self.showGenerationSettings;
    
    self.historyMenu = nil;
}

- (IBAction)onGenerate:(id)sender {
    PasswordGenerationConfig* config = AppPreferences.sharedInstance.passwordGenerationConfig;
    [self setPassword:[PasswordMaker.sharedInstance generateForConfigOrDefault:config]];
}

- (IBAction)onSettings:(id)sender {
    if(self.onPasswordSettings) {
        self.onPasswordSettings();
    }
}

- (NSString *)password {
    return self.passwordBackingStore;
}

- (void)setPassword:(NSString *)password {


    self.passwordBackingStore = password;
    
    [self bindUI];
}

- (void)bindUI {


    BOOL dark = self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark;
    BOOL colorBlind = AppPreferences.sharedInstance.colorizeUseColorBlindPalette;
    
    if ( self.concealPassword ) {
        NSString* secureString = [self getSecureString:self.password.length];
        self.valueTextView.attributedText = [ColoredStringHelper getColorizedAttributedString:secureString
                                                                                     colorize:NO
                                                                                     darkMode:dark
                                                                                   colorBlind:NO
                                                                                         font:self.valueTextView.font];
    }
    else {
        self.valueTextView.attributedText = [ColoredStringHelper getColorizedAttributedString:self.password
                                                                                     colorize:self.colorize
                                                                                     darkMode:dark
                                                                                   colorBlind:colorBlind
                                                                                         font:self.valueTextView.font];
    }
    
    
    UIImage *image = [UIImage systemImageNamed:self.concealPassword ? @"eye" : @"eye.slash"];

    [self.self.buttonToggleConceal setImage:image
                                   forState:UIControlStateNormal];

    self.buttonClearPassword.hidden = self.password.length == 0;



    [self notifyChangedAndLayout];
    [self bindStrength];
}

- (NSString*)getSecureString:(NSUInteger)length {
    NSMutableString *ret = NSMutableString.string;
    
    for (int i = 0; i < length; i++) {
        [ret appendString:@"•"];
    }
    
    return ret.copy;
}

- (void)textViewDidChange:(UITextView *)textView {


    self.password = [NSString stringWithString:textView.textStorage.string];


}

- (void)notifyChangedAndLayout {

      
    if(self.onPasswordEdited) {
        self.onPasswordEdited(self.password);
    }
    
    [self.valueTextView layoutSubviews];
    [[NSNotificationCenter defaultCenter] postNotificationName:CellHeightsChangedNotification object:self];
}

- (BOOL)textView:(UITextView *)textView shouldChangeTextInRange:(NSRange)range replacementText:(NSString *)text {

    
    NSMutableCharacterSet *set = [[NSCharacterSet newlineCharacterSet] mutableCopy];
    [set formUnionWithCharacterSet:[NSCharacterSet characterSetWithCharactersInString:@"\t"]];

    
    
    if( [text rangeOfCharacterFromSet:set].location == NSNotFound ) {
        
        
        UITextPosition *beginning = textView.beginningOfDocument;
        UITextPosition *cursorLocation = [textView positionFromPosition:beginning offset:(range.location + text.length)];

        
        
        
        if ( !self.isInShouldChangeMethod ) { 
            self.isInShouldChangeMethod = YES;
            
            self.password = [self.password stringByReplacingCharactersInRange:range withString:text];
            
            self.isInShouldChangeMethod = NO;
        }
        else {
            slog(@"WARNWARN - Recurse in shouldChangeTextInRange");
        }
        
        
        
        if(cursorLocation) {
            [textView setSelectedTextRange:[textView textRangeFromPosition:cursorLocation toPosition:cursorLocation]];
        }

        return NO;
    }





    
    return NO;
}

- (void)bindStrength {
    [PasswordStrengthUIHelper bindStrengthUI:self.password
                                      config:AppPreferences.sharedInstance.passwordStrengthConfig
                          emptyPwHideSummary:NO
                                       label:self.labelStrength
                                    progress:self.progressStrength];
}

- (IBAction)onToggleConceal:(id)sender {
    self.concealPassword = !self.concealPassword;
    
    [self bindUI];
}

- (IBAction)onClear:(id)sender {
    self.password = @"";
}



- (void)refreshGeneratedMenu {
    PasswordGenerationConfig* config = AppPreferences.sharedInstance.passwordGenerationConfig;
    config.algorithm = config.algorithm == kPasswordGenerationAlgorithmBasic ? kPasswordGenerationAlgorithmDiceware : kPasswordGenerationAlgorithmBasic; 
    
    NSMutableArray* suggestions = [NSMutableArray arrayWithCapacity:3];
    
    [suggestions addObject:[PasswordMaker.sharedInstance generateForConfigOrDefault:AppPreferences.sharedInstance.passwordGenerationConfig]];
    [suggestions addObject:[PasswordMaker.sharedInstance generateForConfigOrDefault:AppPreferences.sharedInstance.passwordGenerationConfig]];
    [suggestions addObject:[PasswordMaker.sharedInstance generateForConfigOrDefault:config]];
    [suggestions addObject:[PasswordMaker.sharedInstance generateForConfigOrDefault:config]];
    
    NSMutableArray<UIMenuElement*>* ma0 = [NSMutableArray array];
    
    __weak EditPasswordTableViewCell* weakSelf = self;
    
    for ( NSString* suggestion in suggestions ) {
        [ma0 addObject:[self getContextualMenuItem:suggestion
                                       systemImage:nil
                                       destructive:NO
                                           enabled:YES
                                           checked:NO
                                           handler:^(__kindof UIAction * _Nonnull action) {
            [weakSelf setPassword:action.title];
        }]];
    }
    
    UIMenu* menu0 = [UIMenu menuWithTitle:@""
                                    image:nil
                               identifier:nil
                                  options:UIMenuOptionsDisplayInline
                                 children:ma0];
    
    
    
    NSMutableArray* altSuggestions = [NSMutableArray arrayWithCapacity:3];
    
    [altSuggestions addObject:[PasswordMaker.sharedInstance generateUsername].lowercaseString];
    [altSuggestions addObject:@(arc4random()).stringValue];
    [altSuggestions addObject:[PasswordMaker.sharedInstance generateEmail]];
    [altSuggestions addObject:[PasswordMaker.sharedInstance generateRandomWord]];
    
    NSMutableArray<UIMenuElement*>* ma05 = [NSMutableArray array];
    for ( NSString* suggestion in altSuggestions ) {
        [ma05 addObject:[self getContextualMenuItem:suggestion
                                        systemImage:nil
                                        destructive:NO
                                            enabled:YES
                                            checked:NO
                                            handler:^(__kindof UIAction * _Nonnull action) {
            [weakSelf setPassword:action.title];
        }]];
    }
    
    UIMenu* menu05 = [UIMenu menuWithTitle:@""
                                     image:nil
                                identifier:nil
                                   options:UIMenuOptionsDisplayInline
                                  children:ma05];
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    UIMenu* menu = [UIMenu menuWithTitle:@""
                                   image:nil
                              identifier:nil
                                 options:kNilOptions
                                children:@[menu0, menu05]]; 
    
    self.buttonGenerate.menu = menu;
}

- (UIAction*)getContextualMenuItem:(NSString*)title systemImage:(NSString*)systemImage handler:(UIActionHandler)handler   {
    return [self getContextualMenuItem:title systemImage:systemImage destructive:NO handler:handler];
}

- (UIAction*)getContextualMenuItem:(NSString*)title systemImage:(NSString*)systemImage destructive:(BOOL)destructive handler:(UIActionHandler)handler   {
    return [self getContextualMenuItem:title systemImage:systemImage destructive:destructive enabled:YES checked:NO handler:handler];
}

- (UIAction*)getContextualMenuItem:(NSString*)title systemImage:(NSString*_Nullable)systemImage destructive:(BOOL)destructive enabled:(BOOL)enabled checked:(BOOL)checked handler:(UIActionHandler)handler
   {
    return [self getContextualMenuItem:title
                                 image:systemImage ? [UIImage systemImageNamed:systemImage] : nil
                           destructive:destructive
                               enabled:enabled
                               checked:checked
                               handler:handler];
}

- (UIAction*)getContextualMenuItem:(NSString*)title image:(UIImage*)image destructive:(BOOL)destructive handler:(UIActionHandler)handler  {
    return [self getContextualMenuItem:title image:image destructive:destructive enabled:YES checked:NO handler:handler];
}

- (UIAction*)getContextualMenuItem:(NSString*)title image:(UIImage*_Nullable)image destructive:(BOOL)destructive enabled:(BOOL)enabled checked:(BOOL)checked handler:(UIActionHandler)handler
   {
    UIAction *ret = [UIAction actionWithTitle:title
                                        image:image
                                   identifier:nil
                                      handler:handler];
    
    if (destructive) {
        ret.attributes = UIMenuElementAttributesDestructive;
    }
        
    if (!enabled) {
        ret.attributes = UIMenuElementAttributesDisabled;
    }
    
    if (checked) {
        ret.state = UIMenuElementStateOn;
    }
    
    return ret;
}

- (UIMenu *)historyMenu {
    return self.buttonHistory.menu;
}

- (void)setHistoryMenu:(UIMenu *)historyMenu {
    self.buttonHistory.menu = historyMenu;
    self.buttonHistory.hidden = historyMenu == nil;
}

@end
