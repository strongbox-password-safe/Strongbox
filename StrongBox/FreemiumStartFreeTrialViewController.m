//
//  FreemiumStartFreeTrialViewController.m
//  Strongbox
//
//  Created by Mark on 03/04/2020.
//  Copyright © 2020 Mark McGuill. All rights reserved.
//

#import "FreemiumStartFreeTrialViewController.h"
#import "ProUpgradeIAPManager.h"
#import "SVProgressHUD.h"
#import "Alerts.h"
#import "SharedAppAndAutoFillSettings.h"

@interface FreemiumStartFreeTrialViewController ()

@property (weak, nonatomic) IBOutlet UIButton *buttonRestorePurchases;

@property (weak, nonatomic) IBOutlet UIView *startButton;
@property (weak, nonatomic) IBOutlet UILabel *startButtonL1;
@property (weak, nonatomic) IBOutlet UILabel *startButtonL2;
@property (weak, nonatomic) IBOutlet UILabel *startButtonL3;
@property (weak, nonatomic) IBOutlet UITextView *textViewTC;

@end

@implementation FreemiumStartFreeTrialViewController

- (BOOL)shouldAutorotate {
    if ( UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad ) {
        return YES; /* Device is iPad */
    }
    else {
        return NO;
    }
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    if ( UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad ) {
        return UIInterfaceOrientationMaskAll; /* Device is iPad */
    }
    else {
        return UIInterfaceOrientationMaskPortrait;
    }
}

- (void)viewDidLoad {
    [super viewDidLoad];

    [self setupUi];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    
    [self.textViewTC setContentOffset:CGPointZero animated:NO];
}

- (void)setupUi {
    UITapGestureRecognizer *trial = [[UITapGestureRecognizer alloc] initWithTarget:self
                                                                            action:@selector(onStartTrial:)];
    [self.startButton addGestureRecognizer:trial];

    NSString* loc2 = NSLocalizedString(@"upgrade_vc_start_your_free_trial_price_free", @"Free");
    NSString* loc3 = NSLocalizedString(@"onboarding_vc_start_your_free_trial_subtitle_no_subscription", @"No Subscription Required");

    self.startButton.layer.cornerRadius = 5.0f;
    self.startButtonL2.text = loc2;
    self.startButtonL3.text = loc3;
}

- (IBAction)onStartTrial:(id)sender {
    self.buttonRestorePurchases.enabled = NO;
    self.startButton.userInteractionEnabled = NO;
    self.startButton.backgroundColor = UIColor.systemGrayColor;
    
    [SVProgressHUD showWithStatus:NSLocalizedString(@"generic_loading", @"Loading...")];
    
    [ProUpgradeIAPManager.sharedInstance startFreeTrial:^(NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [SVProgressHUD dismiss];
            self.startButton.userInteractionEnabled = YES;
            self.startButton.backgroundColor = UIColor.systemBlueColor;
            
            NSLog(@"Purchases done... [%@]", error);

            if (!error) {
                self.onDone(YES);
            }
            else {
                [Alerts error:self title:NSLocalizedString(@"generic_error", @"Error") error:error];
            }
        });
    }];
}

- (IBAction)onRestorePurchases:(id)sender {
    self.buttonRestorePurchases.enabled = NO;
    self.startButton.userInteractionEnabled = NO;
    [SVProgressHUD showWithStatus:NSLocalizedString(@"upgrade_vc_progress_restoring", @"Restoring...")];
    
    BOOL optedInToFreeTrial = SharedAppAndAutoFillSettings.sharedInstance.hasOptedInToFreeTrial;
    
    [ProUpgradeIAPManager.sharedInstance restorePrevious:^(NSError * _Nonnull error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            self.buttonRestorePurchases.enabled = YES;
            self.startButton.userInteractionEnabled = YES;
            [SVProgressHUD dismiss];
            
            if(error) {
                [Alerts error:self
                        title:NSLocalizedString(@"upgrade_vc_problem_restoring", @"Issue Restoring Purchase")
                        error:error];
            }
            else {
                BOOL freeTrialStarted = SharedAppAndAutoFillSettings.sharedInstance.hasOptedInToFreeTrial != optedInToFreeTrial;
                
                if(!SharedAppAndAutoFillSettings.sharedInstance.isPro && !freeTrialStarted) {
                    [Alerts info:self
                           title:NSLocalizedString(@"upgrade_vc_restore_unsuccessful_title", @"Restoration Unsuccessful")
                         message:NSLocalizedString(@"upgrade_vc_restore_unsuccessful_message", @"Upgrade could not be restored from previous purchase. Are you sure you have purchased this item?")
                      completion:nil];
                }
                else {
                    self.onDone(YES);
                }
            }
        });
    }];

}

- (IBAction)onDismiss:(id)sender {
    self.onDone(NO);
}

@end
