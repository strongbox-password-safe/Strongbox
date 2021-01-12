//
//  PinEntryController.m
//  Strongbox
//
//  Created by Mark on 11/01/2019.
//  Copyright © 2019 Mark McGuill. All rights reserved.
//

#import "PinEntryController.h"
#import "SharedAppAndAutoFillSettings.h"

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

@property (weak, nonatomic) IBOutlet UILabel *labelWhichPIN;

@end

@implementation PinEntryController

- (BOOL)shouldAutorotate {
    if ( UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad )
    {
        return YES; /* Device is iPad */
    }
    else {
        return NO;
    }
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    if ( UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad )
    {
        return UIInterfaceOrientationMaskAll; /* Device is iPad */
    }
    else {
        return UIInterfaceOrientationMaskPortrait;
    }
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    [self setupUi];

    self.buttonFallback.hidden = !self.showFallbackOption;
    
    
    
    self.buttonDone.hidden = self.pinLength > 0 && SharedAppAndAutoFillSettings.sharedInstance.instantPinUnlocking;
    
    self.labelWarning.text = self.warning;
    self.labelWarning.hidden = self.warning.length == 0;
    if(self.warning.length) {
        if (@available(iOS 11.0, *)) {
            [self.stackView setCustomSpacing:8 afterView:self.logo];
        }
        else {
            [self.stackView setSpacing:4]; 
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
    CGFloat ROUND_BUTTON_WIDTH_HEIGHT = 65.0; 
    
    button.clipsToBounds = YES;
    button.layer.cornerRadius = ROUND_BUTTON_WIDTH_HEIGHT/2.0f;
    button.layer.borderWidth = 1.0f;
    if (@available(iOS 13.0, *)) {
        button.layer.borderColor = UIColor.systemGrayColor.CGColor;
    } else {
        button.layer.borderColor = UIColor.darkGrayColor.CGColor;
    }
    
    if (@available(iOS 13.0, *)) {
        [button setTitleColor:UIColor.labelColor forState:UIControlStateNormal];
        [button setTitleColor:UIColor.labelColor forState:UIControlStateHighlighted];
    } else {
        [button setTitleColor:UIColor.darkGrayColor forState:UIControlStateNormal];
        [button setTitleColor:UIColor.darkGrayColor forState:UIControlStateNormal];
    }
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
        
        if(self.enteredText.length > 0) {
            self.enteredText = [self.enteredText substringToIndex:self.enteredText.length-1];
            [self performLightHapticFeedback];
        }
    }
    
    [self updateEnteredTextLabel];
    
    [self validateButtonsUi];
    
    if(self.pinLength > 0 && self.enteredText.length == self.pinLength && SharedAppAndAutoFillSettings.sharedInstance.instantPinUnlocking) {
        
        
        
        
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

        if (@available(iOS 13.0, *)) {
            self.labelEnteredText.textColor = UIColor.labelColor;
        }
        else {
            self.labelEnteredText.textColor = nil;
        }
    }
    else {
        NSString* placeholderText = self.isDatabasePIN ? NSLocalizedString(@"pin_entry_database_default_text", @"Database PIN") : NSLocalizedString(@"pin_entry_app_default_text", @"App PIN");
        
        self.labelEnteredText.text = self.info.length ? self.info : placeholderText;
        if (@available(iOS 13.0, *)) {
            self.labelEnteredText.textColor = UIColor.systemGrayColor;
        }
        else {
            self.labelEnteredText.textColor = UIColor.lightGrayColor;
        }
    }
}

@end
