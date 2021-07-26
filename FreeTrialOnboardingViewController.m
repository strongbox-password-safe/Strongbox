//
//  WelcomeFreemiumViewController.m
//  Strongbox
//
//  Created by Mark on 03/04/2020.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import "FreeTrialOnboardingViewController.h"
#import "BiometricsManager.h"
#import "FreemiumStartFreeTrialViewController.h"
#import "ProUpgradeIAPManager.h"
#import "Alerts.h"
#import "SVProgressHUD.h"
#import "Model.h"
#import "AppPreferences.h"

@interface FreeTrialOnboardingViewController ()

@property (weak, nonatomic) IBOutlet UIButton *buttonTryPro;
@property (weak, nonatomic) IBOutlet UIButton *buttonUseFree;
@property (weak, nonatomic) IBOutlet UILabel *labelBiometricUnlockFeature;

@property (weak, nonatomic) IBOutlet UIImageView *imageViewOK1;
@property (weak, nonatomic) IBOutlet UIImageView *imageViewOK2;
@property (weak, nonatomic) IBOutlet UIImageView *imageViewOK3;
@property (weak, nonatomic) IBOutlet UIImageView *imageViewOK4;

@end

@implementation FreeTrialOnboardingViewController

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
        
    
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(onProStatusChanged) name:kProStatusChangedNotificationKey object:nil];
}

- (void)setupUi {
    self.buttonTryPro.layer.cornerRadius = 5.0f;
    self.buttonUseFree.layer.cornerRadius = 5.0f;
    
    
    
    self.imageViewOK1.image = [UIImage imageNamed:@"ok"];
    self.imageViewOK2.image = [UIImage imageNamed:@"ok"];
    self.imageViewOK3.image = [UIImage imageNamed:@"ok"];
    self.imageViewOK4.image = [UIImage imageNamed:@"ok"];

    NSString* loc = NSLocalizedString(@"generic_biometric_unlock_fmt", @"%@ Unlock");
    NSString* fmt = [NSString stringWithFormat:loc, [BiometricsManager.sharedInstance getBiometricIdName]];
    self.labelBiometricUnlockFeature.text = fmt;
}

- (IBAction)onTryPro:(id)sender {
    [NSNotificationCenter.defaultCenter removeObserver:self];
    [self performSegueWithIdentifier:@"segueToStartTrial" sender:nil];
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    FreemiumStartFreeTrialViewController* vc = segue.destinationViewController;
    vc.onDone = ^(BOOL purchasedOrRestoredFreeTrial) {
        if ( purchasedOrRestoredFreeTrial ) {
            [self onDismiss:nil];
        }
    };
}

- (void)onProStatusChanged {
    if ( AppPreferences.sharedInstance.isProOrFreeTrial ) {
        [self onDismiss:nil];
    }
}

- (IBAction)onAskMeLater:(id)sender {
    [self onDismiss:sender];
}

- (IBAction)onDismiss:(id)sender {
    [NSNotificationCenter.defaultCenter removeObserver:self];

    __weak FreeTrialOnboardingViewController* weakSelf = self;

    dispatch_async(dispatch_get_main_queue(), ^{
        if ( weakSelf.onDone ) {
            weakSelf.onDone(NO, NO);
            weakSelf.onDone = nil; 
        }
    });
}

@end
