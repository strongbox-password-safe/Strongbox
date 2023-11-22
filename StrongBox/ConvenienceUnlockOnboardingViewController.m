//
//  ConvenienceUnlockOnboardingViewController.m
//  Strongbox
//
//  Created by Strongbox on 11/05/2021.
//  Copyright © 2021 Mark McGuill. All rights reserved.
//

#import "ConvenienceUnlockOnboardingViewController.h"
#import "BiometricsManager.h"
#import "AppPreferences.h"
#import "PinEntryController.h"
#import "Alerts.h"
#import "RoundedBlueButton.h"
#import "DatabasePreferences.h"

@interface ConvenienceUnlockOnboardingViewController ()

@property (weak, nonatomic) IBOutlet UILabel *labelMessage;
@property (weak, nonatomic) IBOutlet UIImageView *imageView;
@property (weak, nonatomic) IBOutlet RoundedBlueButton *buttonUseBio;

@end

@implementation ConvenienceUnlockOnboardingViewController

- (BOOL)shouldAutorotate {
    return UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad;
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad ? UIInterfaceOrientationMaskAll : UIInterfaceOrientationMaskPortrait;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    NSString* fmt = NSLocalizedString(@"onboarding_convenience_message_fmt", @"Typing your master password is slow, cumbersome and error prone. Strongbox can help you to conveniently and securely unlock your database so that you don't need to enter your master password all the time.\n\nWould you like to use Convenience Unlock?");
    
    self.labelMessage.text = fmt;
    
    NSString* biometricIdName = [BiometricsManager.sharedInstance getBiometricIdName];
    NSString* button = [NSString stringWithFormat:NSLocalizedString(@"open_sequence_prompt_use_convenience_use_bio_fmt", @"Use %@"), biometricIdName];
    [self.buttonUseBio setTitle:button forState:UIControlStateNormal];

    if ( BiometricsManager.isBiometricIdAvailable ) {
        if ( BiometricsManager.sharedInstance.isFaceId ) {
            self.imageView.image = [UIImage imageNamed:@"face_ID"];
        }
        else {
            self.imageView.image = [UIImage imageNamed:@"biometric"];
        }
    }
    else {
        self.buttonUseBio.hidden = YES;
        self.imageView.image = [UIImage imageNamed:@"keypad"];
    }
}

- (IBAction)onUseBio:(id)sender {
    [BiometricsManager.sharedInstance requestBiometricId:NSLocalizedString(@"open_sequence_biometric_unlock_prompt_title", @"Identify to Unlock Database")
                                           fallbackTitle:@""
                                              completion:^(BOOL success, NSError * _Nullable error) {
        if ( success ) {
            dispatch_async(dispatch_get_main_queue(), ^{
                self.model.metadata.isTouchIdEnabled = YES;
                self.model.metadata.conveniencePasswordHasBeenStored = YES;
                self.model.metadata.convenienceMasterPassword = self.model.database.ckfs.password;
                self.model.metadata.hasBeenPromptedForConvenience = YES;
                
                if ( self.onDone ) {
                    self.onDone(NO, NO);
                }
            });
        }
    }];
}

- (IBAction)onUsePin:(id)sender {
    [self setupConveniencePinAndOpen];
}

- (IBAction)onUseNone:(id)sender {
    self.model.metadata.isTouchIdEnabled = NO;
    self.model.metadata.conveniencePin = nil;
    self.model.metadata.conveniencePasswordHasBeenStored = NO;
    self.model.metadata.convenienceMasterPassword = nil;
    self.model.metadata.autoFillConvenienceAutoUnlockPassword = nil;
    self.model.metadata.hasBeenPromptedForConvenience = YES;
    
    if ( self.onDone ) {
        self.onDone(NO, NO);
    }
}

- (void)enrolForPinCodeUnlock:(NSString*)pin {
    self.model.metadata.conveniencePin = pin;
    self.model.metadata.conveniencePasswordHasBeenStored = YES;
    self.model.metadata.convenienceMasterPassword = self.model.database.ckfs.password;
    self.model.metadata.hasBeenPromptedForConvenience = YES;
    
    if ( self.onDone ) {
        self.onDone(NO, NO);
    }
}

- (void)setupConveniencePinAndOpen {
    PinEntryController* pinEntryVc = PinEntryController.newControllerForDatabaseUnlock;
    
    pinEntryVc.onDone = ^(PinEntryResponse response, NSString * _Nullable pin) {
        if( response == kPinEntryResponseOk ) {
            if(!(self.model.metadata.duressPin != nil && [pin isEqualToString:self.model.metadata.duressPin])) {
                [self enrolForPinCodeUnlock:pin];
            }
            else {
                [Alerts warn:self
                       title:NSLocalizedString(@"open_sequence_warn_pin_conflict_title", @"PIN Conflict")
                    message:NSLocalizedString(@"open_sequence_warn_pin_conflict_message", @"Your Convenience PIN conflicts with your Duress PIN. Please configure in Database Settings")
                completion:^{
                    [self onUseNone:nil];
                }];
            }
        }
    };

    [self presentViewController:pinEntryVc animated:YES completion:nil];
}

- (IBAction)onDismiss:(id)sender {
    if ( self.onDone ) {
        self.onDone(NO, YES);
    }
}

@end
