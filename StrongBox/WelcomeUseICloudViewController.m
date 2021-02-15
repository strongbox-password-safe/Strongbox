//
//  WelcomeUseICloudViewController.m
//  Strongbox-iOS
//
//  Created by Mark on 17/07/2019.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import "WelcomeUseICloudViewController.h"
#import "WelcomeCreateDatabaseViewController.h"
#import "Settings.h"
#import "SafesList.h"
#import "SharedAppAndAutoFillSettings.h"
#import "iCloudSafesCoordinator.h"
#import "AutoFillManager.h"
#import "WelcomeAddDatabaseViewController.h"
#import "TurnOnAutoFillViewController.h"
#import "SVProgressHUD.h"
#import "AllSetAlreadyHasDatabaseViewController.h"

@interface WelcomeUseICloudViewController ()

@property (weak, nonatomic) IBOutlet UIButton *useICloud;
@property (weak, nonatomic) IBOutlet UIButton *dontUseICloud;

@property NSMetadataQuery* query;

@end

@implementation WelcomeUseICloudViewController

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
    
    self.useICloud.layer.cornerRadius = 5.0f;
    self.dontUseICloud.layer.cornerRadius = 5.0f;
}

- (IBAction)onUseICloud:(id)sender {
    [self enableICloudAndContinue:YES];
}

- (IBAction)onDoNotUseICloud:(id)sender {
    [self enableICloudAndContinue:NO];
}

- (void)enableICloudAndContinue:(BOOL)enable {
    if (enable) {
        SharedAppAndAutoFillSettings.sharedInstance.iCloudOn = enable; 
        Settings.sharedInstance.iCloudWasOn = enable; 

        [iCloudSafesCoordinator.sharedInstance startQuery];
        
        [SVProgressHUD showWithStatus:NSLocalizedString(@"generic_loading", @"Loading...")];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [SVProgressHUD dismiss];
            
            [self.query stopQuery];
            self.query = nil;
            
            if (AutoFillManager.sharedInstance.isPossible && !AutoFillManager.sharedInstance.isOnForStrongbox) {
                [self performSegueWithIdentifier:@"segueICloudToAutoFill" sender:nil];
            }
            else {
                if (SafesList.sharedInstance.snapshot.count != 0) {
                    [self performSegueWithIdentifier:@"segueiCloudToAlreadyHasDatabase" sender:nil];
                }
                else {
                    [self performSegueWithIdentifier:@"segueICloudToAddDatabase" sender:nil];
                }
            }
        });
    }
    else {
        if (AutoFillManager.sharedInstance.isPossible && !AutoFillManager.sharedInstance.isOnForStrongbox) {
            [self performSegueWithIdentifier:@"segueICloudToAutoFill" sender:nil];
        }
        else {
            [self performSegueWithIdentifier:@"segueICloudToAddDatabase" sender:nil];
        }
    }
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([segue.identifier isEqualToString:@"segueICloudToAddDatabase"]) {
        WelcomeAddDatabaseViewController* vc = (WelcomeAddDatabaseViewController*)segue.destinationViewController;
        vc.onDone = self.onDone;
    }
    else if ([segue.identifier isEqualToString:@"segueICloudToAutoFill"]) {
        TurnOnAutoFillViewController* vc = (TurnOnAutoFillViewController*)segue.destinationViewController;
        vc.onDone = self.onDone;
    }
    else if ([segue.identifier isEqualToString:@"segueiCloudToAlreadyHasDatabase"]) {
        AllSetAlreadyHasDatabaseViewController* vc = (AllSetAlreadyHasDatabaseViewController*)segue.destinationViewController;
        vc.onDone = self.onDone;
    }
}

- (IBAction)onDismiss:(id)sender {
    self.onDone(NO, nil);
}

@end
