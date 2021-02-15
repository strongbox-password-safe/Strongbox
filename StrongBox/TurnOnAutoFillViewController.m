//
//  TurnOnAutoFillViewController.m
//  Strongbox
//
//  Created by Strongbox on 18/08/2020.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import "TurnOnAutoFillViewController.h"
#import "WelcomeAddDatabaseViewController.h"
#import "AutoFillManager.h"
#import "SafesList.h"
#import "AllSetAlreadyHasDatabaseViewController.h"

@interface TurnOnAutoFillViewController ()

@property (weak, nonatomic) IBOutlet UIButton *buttonDone;
@property (weak, nonatomic) IBOutlet UIButton *buttonDismiss;

@end

@implementation TurnOnAutoFillViewController

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

    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(appBecameActive)
                                               name:UIApplicationDidBecomeActiveNotification
                                             object:nil];

    self.buttonDone.layer.cornerRadius = 5.0f;
}

- (void)appBecameActive {
    if (AutoFillManager.sharedInstance.isOnForStrongbox) {
        NSLog(@"AutoFill has been switched on!");
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(.3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self onDone:nil];
        });
    }
    else {
        NSLog(@"AutoFill has not been switched on!");
    }
}

- (IBAction)onDone:(id)sender {
    [NSNotificationCenter.defaultCenter removeObserver:self];
    
    if (SafesList.sharedInstance.snapshot.count != 0) {
        [self performSegueWithIdentifier:@"segueAutoFillToAlreadyHasDatabase" sender:nil];
    }
    else {
        [self performSegueWithIdentifier:@"segueAutoFillToAddFirst" sender:nil];
    }
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if([segue.identifier isEqualToString:@"segueAutoFillToAddFirst"]) {
        WelcomeAddDatabaseViewController* vc = (WelcomeAddDatabaseViewController*)segue.destinationViewController;
        vc.onDone = self.onDone;
    }
    else if ([segue.identifier isEqualToString:@"segueAutoFillToAlreadyHasDatabase"]) {
        AllSetAlreadyHasDatabaseViewController* vc = (AllSetAlreadyHasDatabaseViewController*)segue.destinationViewController;
        vc.onDone = self.onDone;
    }
}

- (IBAction)onDismiss:(id)sender {
    [NSNotificationCenter.defaultCenter removeObserver:self];
    
    self.onDone(NO, nil);
}

@end
