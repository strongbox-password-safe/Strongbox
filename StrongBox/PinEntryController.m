//
//  PinEntryController.m
//  Strongbox
//
//  Created by Mark on 11/01/2019.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import "PinEntryController.h"
#import "AppPreferences.h"
#import "FontManager.h"
#import "Utils.h"

@interface PinEntryController () <UIAdaptivePresentationControllerDelegate>

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
@property (weak, nonatomic) IBOutlet UIButton *buttonCancel;

@property (weak, nonatomic) IBOutlet UIButton *buttonDone;
@property (weak, nonatomic) IBOutlet UIButton *buttonFallback;

@property NSString* enteredText;
@property (weak, nonatomic) IBOutlet UILabel *labelEnteredText;
@property (weak, nonatomic) IBOutlet UIImageView *logo;
@property (weak, nonatomic) IBOutlet UIStackView *stackView;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *topConstraint;
@property (weak, nonatomic) IBOutlet UIStackView *bottomButtonsStack;
@property (weak, nonatomic) IBOutlet UIStackView *keyPadRowsStack;
@property (weak, nonatomic) IBOutlet UIButton *buttonDeleteCancel;

@property (readonly) UIColor* borderColor;
@property (readonly) UIColor* labelColor;

@property BOOL isDatabasePIN;

@end

@implementation PinEntryController

+ (instancetype)newControllerForAppLock {
    return [PinEntryController instantiateFromStoryboard:NO];
}

+ (instancetype)newControllerForDatabaseUnlock {
    return [PinEntryController instantiateFromStoryboard:YES];
}

+ (instancetype)instantiateFromStoryboard:(BOOL)databasePIN {
    UIStoryboard* storyboard = [UIStoryboard storyboardWithName:@"PinEntry" bundle:nil];
    PinEntryController* vc1 = (PinEntryController*)[storyboard instantiateInitialViewController];
    
    vc1.isDatabasePIN = databasePIN;
    vc1.modalInPresentation = !Utils.isiPad;
    
    vc1.modalPresentationStyle = Utils.isiPad ? UIModalPresentationFormSheet : UIModalPresentationFullScreen;
    
    return vc1;
}

- (BOOL)shouldAutorotate {
    return UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad;
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad ? UIInterfaceOrientationMaskAll : UIInterfaceOrientationMaskPortrait;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    self.presentationController.delegate = self;

    [self setupUi];
    
    [self adjustForOrientation];
    
    [self updateEnteredTextLabel];
    [self validateButtonsUi];
}

- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator {

    [self adjustForOrientation];
}

- (void)adjustForOrientation {
    if ( UIDeviceOrientationIsLandscape([UIDevice currentDevice].orientation) &&  UIDevice.currentDevice.userInterfaceIdiom != UIUserInterfaceIdiomPad ) {
        self.logo.hidden = YES;

        
        [self.stackView setCustomSpacing:0 afterView:self.logo];
        [self.stackView setCustomSpacing:0 afterView:self.labelWarning];
        [self.stackView setCustomSpacing:0 afterView:self.labelEnteredText];
        
        
        self.keyPadRowsStack.spacing = 0.0f;
        
        self.labelEnteredText.font = FontManager.sharedInstance.regularFont;
    }
    else {
        self.logo.hidden = NO;
        self.bottomButtonsStack.hidden = NO;
        
        [self.stackView setCustomSpacing:12 afterView:self.logo];
        [self.stackView setCustomSpacing:12 afterView:self.labelWarning];
        [self.stackView setCustomSpacing:12 afterView:self.labelEnteredText];
    
        self.keyPadRowsStack.spacing = 10.0f;
        
        self.labelEnteredText.font = FontManager.sharedInstance.title1Font;
    }
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
    
    self.buttonDelete.backgroundColor = UIColor.clearColor;
    self.buttonCancel.backgroundColor = UIColor.clearColor;
    
    self.buttonDelete.enabled = NO;
    self.buttonCancel.enabled = NO;
    
    [self.buttonDelete setTitle:@"" forState:UIControlStateNormal];
    [self.buttonCancel setTitle:@"" forState:UIControlStateNormal];
    
    
    self.buttonFallback.hidden = !self.showFallbackOption;

    

    
    
    
    if ( self.pinLength > 0 && AppPreferences.sharedInstance.instantPinUnlocking ) {
        self.buttonDone.alpha = 0.0;
    }
    else {
        self.buttonDone.alpha = 1.0;
    }
    
    self.labelWarning.text = self.warning;
    self.labelWarning.hidden = self.warning.length == 0;
    if(self.warning.length) {
        [self.stackView setCustomSpacing:4 afterView:self.logo];
    }
    
    self.enteredText = @"";
}

- (UIColor*)labelColor {
    return UIColor.labelColor;
}

- (UIColor*)borderColor {
    return UIColor.systemGrayColor;
}

- (void)styleKeyPadButton:(UIButton*)button {
    const CGFloat buttonWidth = button.frame.size.width;
    
    UIColor* backgroundColor = UIColor.clearColor;
    UIColor* insideCircleColor = UIColor.quaternaryLabelColor;

    
    
    UIBezierPath* circlePath = [UIBezierPath bezierPathWithArcCenter:CGPointMake(buttonWidth/2, buttonWidth/2) radius:42.0f startAngle:0 endAngle:M_PI * 2 clockwise:YES];
    
    CAShapeLayer* circleLayer = CAShapeLayer.layer;
    circleLayer.path = circlePath.CGPath;
    circleLayer.fillColor = insideCircleColor.CGColor;

    


    
    
    [button.layer addSublayer:circleLayer];
    
    button.layer.cornerRadius = buttonWidth/2.0f;
    button.clipsToBounds = NO;

    






    button.backgroundColor = backgroundColor;

    [button setTitleColor:self.labelColor forState:UIControlStateNormal];
    [button setTitleColor:self.labelColor forState:UIControlStateHighlighted];
}

- (IBAction)onOK:(id)sender {
    __weak PinEntryController* weakSelf = self;
    [self.presentingViewController dismissViewControllerAnimated:YES completion:^{
        weakSelf.onDone(kPinEntryResponseOk, weakSelf.enteredText);
    }];
}

- (IBAction)onCancel:(id)sender {
    __weak PinEntryController* weakSelf = self;
    [self.presentingViewController dismissViewControllerAnimated:YES completion:^{
        weakSelf.onDone(kPinEntryResponseCancel, nil);
    }];
}

- (IBAction)onUseMasterCredentials:(id)sender {
    __weak PinEntryController* weakSelf = self;
    [self.presentingViewController dismissViewControllerAnimated:YES completion:^{
        weakSelf.onDone(kPinEntryResponseFallback, nil);
    }];
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
    
    [self bindUI];
    
    if(self.pinLength > 0 && self.enteredText.length == self.pinLength && AppPreferences.sharedInstance.instantPinUnlocking) {
        
        
        
        
        [self onOK:nil];
    }
}

- (void)bindUI {
    [self updateEnteredTextLabel];
    
    [self validateButtonsUi];
}

- (void)validateButtonsUi {
    if ( self.pinLength > 0 && AppPreferences.sharedInstance.instantPinUnlocking ) {
        self.buttonDone.enabled = NO;
    }
    else {
        self.buttonDone.enabled = self.enteredText.length > 3;
    }
    
    self.buttonDelete.enabled = self.enteredText.length > 0;
    [self.buttonDelete setTitleColor:self.enteredText.length > 0 ? self.labelColor : UIColor.lightGrayColor forState:UIControlStateNormal];
    
    NSString* title = self.enteredText.length > 0 ? NSLocalizedString(@"generic_action_delete", @"Delete") : NSLocalizedString(@"generic_cancel", @"Cancel");
    
    [UIView performWithoutAnimation:^{
        [self.buttonDeleteCancel setTitle:title forState:UIControlStateNormal];
        [self.buttonDeleteCancel layoutIfNeeded];
    }];
}

- (void)updateEnteredTextLabel {
    if(self.enteredText.length) {
        NSString *masked = [@"" stringByPaddingToLength:self.enteredText.length withString:@"●" startingAtIndex:0];
        
        self.labelEnteredText.text = masked;
        self.labelEnteredText.textColor = UIColor.labelColor;
    }
    else {
        NSString* placeholderText = self.isDatabasePIN ? NSLocalizedString(@"pin_entry_database_default_text", @"Database PIN") : NSLocalizedString(@"pin_entry_app_default_text", @"App PIN");
        
        self.labelEnteredText.text = self.info.length ? self.info : placeholderText;
        self.labelEnteredText.textColor = UIColor.systemGrayColor;
    }
}

- (void)presentationControllerDidDismiss:(UIPresentationController *)presentationController {

    
    self.onDone(kPinEntryResponseCancel, nil); 
}

- (void)performLightHapticFeedback {
    if ( AppPreferences.sharedInstance.pinCodeHapticFeedback ) {
        UIImpactFeedbackGenerator* gen = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
        [gen impactOccurred];
    }
}

- (IBAction)onDeleteOrCancel:(id)sender {
    if ( self.enteredText.length > 0 ) {
        self.enteredText = [self.enteredText substringToIndex:self.enteredText.length-1];
        [self performLightHapticFeedback];
        [self bindUI];
    }
    else {
        [self onCancel:nil];
    }
}

@end
