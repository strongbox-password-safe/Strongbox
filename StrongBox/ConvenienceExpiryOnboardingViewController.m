//
//  ConvenienceExpiryOnboardingViewController.m
//  Strongbox
//
//  Created by Strongbox on 17/05/2021.
//  Copyright © 2021 Mark McGuill. All rights reserved.
//

#import "ConvenienceExpiryOnboardingViewController.h"
#import "RoundedBlueButton.h"
#import "DatabasePreferences.h"

@interface ConvenienceExpiryOnboardingViewController ()

@property (weak, nonatomic) IBOutlet RoundedBlueButton *buttonDontRemindMe;
@property (weak, nonatomic) IBOutlet UIStackView *stackView;

@end

@implementation ConvenienceExpiryOnboardingViewController

- (BOOL)shouldAutorotate {
    return UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad;
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad ? UIInterfaceOrientationMaskAll : UIInterfaceOrientationMaskPortrait;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.buttonDontRemindMe.backgroundColor = UIColor.systemOrangeColor;
    
    if (@available(iOS 11.0, *)) {
        [self.stackView setCustomSpacing:8.0f afterView:self.buttonDontRemindMe];
    }
}

- (IBAction)onDontRemindMe:(id)sender {
    [self setExpiryAndExitModule:-1];
}

- (IBAction)onOnceAWeek:(id)sender {
    [self setExpiryAndExitModule:(7 * 24)];
}

- (IBAction)onOnceEveryTwoWeeks:(id)sender {
    [self setExpiryAndExitModule:(14 * 24)];
}

- (void)setExpiryAndExitModule:(NSInteger)expiryHours {
    self.model.metadata.convenienceExpiryOnboardingDone = YES;
    self.model.metadata.convenienceExpiryPeriod = expiryHours;
    self.model.metadata.convenienceMasterPassword = self.model.database.ckfs.password;

    if ( self.onDone ) {
        self.onDone(NO, NO);
    }
}

- (IBAction)onDismiss:(id)sender {
    if ( self.onDone ) {
        self.onDone(NO, YES);
    }
}

@end
