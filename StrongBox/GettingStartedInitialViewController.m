//
//  GettingStartedInitialViewController.m
//  Strongbox
//
//  Created by Strongbox on 18/08/2020.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import "GettingStartedInitialViewController.h"
#import "AutoFillManager.h"
//#import "Settings.h"
#import "AppPreferences.h"
#import "WelcomeUseICloudViewController.h"
#import "WelcomeAddDatabaseViewController.h"
#import "TurnOnAutoFillViewController.h"
#import "SafesList.h"
#import "AllSetAlreadyHasDatabaseViewController.h"

@interface GettingStartedInitialViewController ()

@property (weak, nonatomic) IBOutlet UIButton *buttonOKLetsDoIt;

@end

@implementation GettingStartedInitialViewController

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

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    self.navigationController.navigationBar.hidden = YES;
    [self.navigationController setNavigationBarHidden:YES];
    
    self.navigationController.toolbarHidden = YES;
    self.navigationController.toolbar.hidden = YES;
    
    [self.navigationItem setPrompt:nil];
}

- (void)viewDidLoad {
    [super viewDidLoad];

    self.buttonOKLetsDoIt.layer.cornerRadius = 5.0f;
}

- (IBAction)onOKLetsDoIt:(id)sender {
    if(AppPreferences.sharedInstance.iCloudAvailable &&
       !AppPreferences.sharedInstance.iCloudOn) {
        [self performSegueWithIdentifier:@"segueToUseICloud" sender:nil];
    }
    else {
        if (AutoFillManager.sharedInstance.isPossible && !AutoFillManager.sharedInstance.isOnForStrongbox) {
            [self performSegueWithIdentifier:@"segueToTurnOnAutoFill" sender:nil];
        }
        else {
            if (SafesList.sharedInstance.snapshot.count != 0) { 
                [self performSegueWithIdentifier:@"segueToAllSetDone" sender:nil];
            }
            else {
                [self performSegueWithIdentifier:@"segueToAddCreateDatabase" sender:nil];
            }
        }
    }
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if([segue.identifier isEqualToString:@"segueToUseICloud"]) {
        WelcomeUseICloudViewController* vc = (WelcomeUseICloudViewController*)segue.destinationViewController;
        vc.onDone = self.onDone;
    }
    else if ([segue.identifier isEqualToString:@"segueToAddCreateDatabase"]) {
        WelcomeAddDatabaseViewController* vc = (WelcomeAddDatabaseViewController*)segue.destinationViewController;
        vc.onDone = self.onDone;
    }
    else if ([segue.identifier isEqualToString:@"segueToTurnOnAutoFill"]) {
        TurnOnAutoFillViewController* vc = (TurnOnAutoFillViewController*)segue.destinationViewController;
        vc.onDone = self.onDone;
    }
    else if ([segue.identifier isEqualToString:@"segueToAllSetDone"]) {
        AllSetAlreadyHasDatabaseViewController* vc = (AllSetAlreadyHasDatabaseViewController*)segue.destinationViewController;
        vc.onDone = self.onDone;
    }
}

- (IBAction)onDismiss:(id)sender {
    self.onDone(NO, nil);
}

@end
