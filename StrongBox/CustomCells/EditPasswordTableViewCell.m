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

@interface EditPasswordTableViewCell () <UITextViewDelegate>

@property (weak, nonatomic) IBOutlet MBAutoGrowingTextView *valueTextView;
@property (weak, nonatomic) IBOutlet UIButton *buttonGenerationSettings;
@property BOOL internalShowGenerationSettings;
@property (weak, nonatomic) IBOutlet UILabel *labelStrength;
@property (weak, nonatomic) IBOutlet UIProgressView *progressStrength;
@property (weak, nonatomic) IBOutlet UIButton *barButtonAlternativeGenerate;
@property (weak, nonatomic) IBOutlet UIButton *buttonGenerate;

@end

@implementation EditPasswordTableViewCell

- (void)awakeFromNib {
    [super awakeFromNib];
  
    self.valueTextView.delegate = self;
    self.valueTextView.font = FontManager.sharedInstance.easyReadFont;
    
    if (@available(iOS 10.0, *)) {
        self.valueTextView.adjustsFontForContentSizeCategory = YES;
    }
    
    self.valueTextView.accessibilityLabel = NSLocalizedString(@"edit_password_cell_value_textfield_accessibility_label", @"Password Text Field");
    
    self.buttonGenerationSettings.hidden = !self.showGenerationSettings;
    
    if (@available(iOS 14.0, *)) { 
        [self.buttonGenerationSettings setImage:[UIImage systemImageNamed:@"gear"] forState:UIControlStateNormal];

        [self.buttonGenerationSettings setPreferredSymbolConfiguration:[UIImageSymbolConfiguration configurationWithScale:UIImageSymbolScaleLarge]
                                                       forImageInState:UIControlStateNormal];

        [self.barButtonAlternativeGenerate setImage:[UIImage systemImageNamed:@"die.face.6"] forState:UIControlStateNormal];
        
        [self.barButtonAlternativeGenerate setPreferredSymbolConfiguration:[UIImageSymbolConfiguration configurationWithScale:UIImageSymbolScaleLarge]
                                                           forImageInState:UIControlStateNormal];
        
        [self.buttonGenerate setImage:[UIImage systemImageNamed:@"arrow.triangle.2.circlepath"] forState:UIControlStateNormal];

        [self.buttonGenerate setPreferredSymbolConfiguration:[UIImageSymbolConfiguration configurationWithScale:UIImageSymbolScaleLarge]
                                                       forImageInState:UIControlStateNormal];
    }
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
    
    self.buttonGenerationSettings.hidden = !self.showGenerationSettings;
}

- (IBAction)onGenerate:(id)sender {
    PasswordGenerationConfig* config = AppPreferences.sharedInstance.passwordGenerationConfig;
    [self setPassword:[PasswordMaker.sharedInstance generateForConfigOrDefault:config]];
}

- (IBAction)onAlternativeGenerate:(id)sender {
    [PasswordMaker.sharedInstance promptWithSuggestions:self.parentVc
                                                 config:AppPreferences.sharedInstance.passwordGenerationConfig
                                                 action:^(NSString * _Nonnull response) {
        [self setPassword:response];
    }];
}

- (IBAction)onSettings:(id)sender {
    if(self.onPasswordSettings) {
        self.onPasswordSettings();
    }
}

- (NSString *)password {
    return [NSString stringWithString:self.valueTextView.textStorage.string];
}

- (void)setPassword:(NSString *)password {
    BOOL dark = NO;
    if (@available(iOS 12.0, *)) {
        dark = self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark;
    }
    BOOL colorBlind = AppPreferences.sharedInstance.colorizeUseColorBlindPalette;
    
    self.valueTextView.attributedText = [ColoredStringHelper getColorizedAttributedString:password
                                                                                 colorize:self.colorize
                                                                                 darkMode:dark
                                                                               colorBlind:colorBlind
                                                                                     font:self.valueTextView.font];
    
    [self notifyChangedAndLayout];
    [self bindStrength];
}

- (void)textViewDidChange:(UITextView *)textView {
    [self notifyChangedAndLayout];
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

        
        
        self.password = [textView.text stringByReplacingCharactersInRange:range withString:text];

        
        
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

@end
