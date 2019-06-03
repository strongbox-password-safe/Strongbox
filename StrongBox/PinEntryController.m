//
//  PinEntryController.m
//  Strongbox
//
//  Created by Mark on 11/01/2019.
//  Copyright © 2019 Mark McGuill. All rights reserved.
//

#import "PinEntryController.h"
#import "Settings.h"

@interface PinEntryController ()

@property (weak, nonatomic) IBOutlet UIButton *button1;
@property (weak, nonatomic) IBOutlet UIButton *button2;
@property (weak, nonatomic) IBOutlet UIButton *button3;
@property (weak, nonatomic) IBOutlet UIButton *button4;
@property (weak, nonatomic) IBOutlet UIButton *button5;
@property (weak, nonatomic) IBOutlet UIButton *button6;
@property (weak, nonatomic) IBOutlet UIButton *button7;
@property (weak, nonatomic) IBOutlet UIButton *button8;
@property (weak, nonatomic) IBOutlet UIButton *button9;
@property (weak, nonatomic) IBOutlet UIButton *button0;
@property (weak, nonatomic) IBOutlet UIButton *buttonDelete;
@property (weak, nonatomic) IBOutlet UILabel *labelWarning;

@property (weak, nonatomic) IBOutlet UIButton *buttonDone;
@property (weak, nonatomic) IBOutlet UIButton *buttonFallback;
@property (weak, nonatomic) IBOutlet UIButton *buttonCancel;

@property NSString* enteredText;
@property (weak, nonatomic) IBOutlet UILabel *labelEnteredText;
@property (weak, nonatomic) IBOutlet UIImageView *logo;
@property (weak, nonatomic) IBOutlet UIStackView *stackView;

@end

@implementation PinEntryController

- (BOOL)shouldAutorotate {
    return NO;
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskPortrait;
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    [self setupUi];

    self.buttonFallback.hidden = !self.showFallbackOption;
    
    // If we're not in auto mode or we're setting PIN then show the done button
    
    self.buttonDone.hidden = self.pinLength > 0 && Settings.sharedInstance.instantPinUnlocking;
    
    self.labelWarning.text = self.warning;
    self.labelWarning.hidden = self.warning.length == 0;
    if(self.warning.length) {
        if (@available(iOS 11.0, *)) {
            [self.stackView setCustomSpacing:8 afterView:self.logo];
        }
        else {
            [self.stackView setSpacing:4]; // Some small screens pre ios 11 might make the cancel button unreachable / warning invisible
        }
    }
    
    self.enteredText = @"";
    
    [self updateEnteredTextLabel];
    [self validateButtonsUi];
}

- (void)setupUi {
    [self styleKeyPadButton:self.button1];
    [self styleKeyPadButton:self.button2];
    [self styleKeyPadButton:self.button3];
    [self styleKeyPadButton:self.button4];
    [self styleKeyPadButton:self.button5];
    [self styleKeyPadButton:self.button6];
    [self styleKeyPadButton:self.button7];
    [self styleKeyPadButton:self.button8];
    [self styleKeyPadButton:self.button9];
    [self styleKeyPadButton:self.button0];
}

- (void)styleKeyPadButton:(UIButton*)button {
    CGFloat ROUND_BUTTON_WIDTH_HEIGHT = 65.0; // Must Match Storyboard constraints
    
    button.clipsToBounds = YES;
    button.layer.cornerRadius = ROUND_BUTTON_WIDTH_HEIGHT/2.0f;
    button.layer.borderWidth = 1.0f;
    button.layer.borderColor = UIColor.darkGrayColor.CGColor;
    
    [button setTitleColor:UIColor.darkGrayColor forState:UIControlStateNormal];
    [button setTitleColor:UIColor.whiteColor forState:UIControlStateHighlighted];
}

- (void)validateButtonsUi {
    self.buttonDone.enabled = self.enteredText.length > 3;
    self.buttonDelete.enabled = self.enteredText.length > 0;

    [self.buttonDelete setTitleColor:self.enteredText.length > 0 ? UIColor.darkGrayColor : UIColor.lightGrayColor forState:UIControlStateNormal];
}

- (IBAction)onOK:(id)sender {
    self.onDone(kOk, self.enteredText);
}

- (IBAction)onCancel:(id)sender {
    self.onDone(kCancel, nil);
}

- (IBAction)onUseMasterCredentials:(id)sender {
    self.onDone(kFallback, nil);
}

- (IBAction)onKeyPadButton:(id)sender {
    UIButton* button = (UIButton*)sender;
    
    if(button.tag >= 0 && button.tag <= 9) {
        self.enteredText = [self.enteredText stringByAppendingFormat:@"%ld", (long)button.tag];
        [self performLightHapticFeedback];
    }
    else {
        // Assume it's the del button
        if(self.enteredText.length > 0) {
            self.enteredText = [self.enteredText substringToIndex:self.enteredText.length-1];
            [self performLightHapticFeedback];
        }
    }
    
    [self updateEnteredTextLabel];
    
    [self validateButtonsUi];
    
    if(self.pinLength > 0 && self.enteredText.length == self.pinLength && Settings.sharedInstance.instantPinUnlocking) {
        // We auto submit at the matching length - This prevents repeated attempts bny using the 3 strikes failure mode
        // If we didn't do this then an attacker could try as many combinations as he liked if he knew you were using
        // Instant PIN mode...
        
        self.onDone(kOk, self.enteredText);
    }
}

- (void)performLightHapticFeedback {
    UIImpactFeedbackGenerator* gen = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
    [gen impactOccurred];
}

- (void)updateEnteredTextLabel {
    if(self.enteredText.length) {
        NSString *masked = [@"" stringByPaddingToLength:self.enteredText.length withString:@"●" startingAtIndex:0];
        
        self.labelEnteredText.text = masked;
        self.labelEnteredText.textColor = UIColor.darkTextColor;
    }
    else {
        self.labelEnteredText.text = self.info.length ? self.info : @"PIN";
        self.labelEnteredText.textColor = UIColor.lightGrayColor;
    }
}

@end
