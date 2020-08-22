//
//  WelcomeFreemiumViewController.m
//  Strongbox
//
//  Created by Mark on 03/04/2020.
//  Copyright © 2020 Mark McGuill. All rights reserved.
//

#import "WelcomeFreemiumViewController.h"
#import "BiometricsManager.h"
#import "FreemiumStartFreeTrialViewController.h"
#import "ProUpgradeIAPManager.h"
#import "Alerts.h"
#import "SVProgressHUD.h"
#import "Settings.h"
#import "Model.h"
#import "SharedAppAndAutoFillSettings.h"

@interface WelcomeFreemiumViewController ()

@property (weak, nonatomic) IBOutlet UIButton *buttonTryPro;
@property (weak, nonatomic) IBOutlet UIButton *buttonUseFree;
@property (weak, nonatomic) IBOutlet UILabel *labelBiometricUnlockFeature;

@property (weak, nonatomic) IBOutlet UIImageView *imageViewOK1;
@property (weak, nonatomic) IBOutlet UIImageView *imageViewOK2;
@property (weak, nonatomic) IBOutlet UIImageView *imageViewOK3;
@property (weak, nonatomic) IBOutlet UIImageView *imageViewOK4;

@end

@implementation WelcomeFreemiumViewController

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

- (void)viewDidLoad {
    [super viewDidLoad];

    [self setupUi];
    
    // Auto - Dismiss if we pick up Pro during display
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(onProStatusChanged) name:kProStatusChangedNotificationKey object:nil];
}

- (void)onProStatusChanged {
    if (SharedAppAndAutoFillSettings.sharedInstance.isProOrFreeTrial) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self onDismiss:nil];
        });
    }
}

- (void)setupUi {
    self.buttonTryPro.layer.cornerRadius = 5.0f;
    self.buttonUseFree.layer.cornerRadius = 5.0f;
    
    // MMcG: Must be done to have the color tint come out ok... at least on iOS 10.x
    
    self.imageViewOK1.image = [UIImage imageNamed:@"ok"];
    self.imageViewOK2.image = [UIImage imageNamed:@"ok"];
    self.imageViewOK3.image = [UIImage imageNamed:@"ok"];
    self.imageViewOK4.image = [UIImage imageNamed:@"ok"];

    NSString* loc = NSLocalizedString(@"generic_biometric_unlock_fmt", @"%@ Unlock");
    NSString* fmt = [NSString stringWithFormat:loc, [BiometricsManager.sharedInstance getBiometricIdName]];
    self.labelBiometricUnlockFeature.text = fmt;
}

- (IBAction)onUseFree:(id)sender {
    [self onDismiss:sender];
}

- (IBAction)onTryPro:(id)sender {
    [NSNotificationCenter.defaultCenter removeObserver:self];
    [self performSegueWithIdentifier:@"segueToStartTrial" sender:nil];
}

- (IBAction)onDismiss:(id)sender {
    [NSNotificationCenter.defaultCenter removeObserver:self];
    self.onDone(NO);
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    FreemiumStartFreeTrialViewController* vc = segue.destinationViewController;
    vc.onDone = self.onDone;
}

@end
