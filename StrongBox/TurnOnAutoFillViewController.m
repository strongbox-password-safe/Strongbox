//
//  TurnOnAutoFillViewController.m
//  Strongbox
//
//  Created by Strongbox on 18/08/2020.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import "TurnOnAutoFillViewController.h"
#import "AutoFillManager.h"
#import "SafesList.h"
#import "RoundedBlueButton.h"
#import "AppPreferences.h"

@interface TurnOnAutoFillViewController ()

@property (weak, nonatomic) IBOutlet UIButton *buttonDone;
@property (weak, nonatomic) IBOutlet RoundedBlueButton *buttonDontUse;

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

    self.buttonDontUse.backgroundColor = UIColor.systemOrangeColor;
}

- (void)appBecameActive {
    if (AutoFillManager.sharedInstance.isOnForStrongbox) {
        NSLog(@"AutoFill has been switched on!");
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(.3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self onSetupLater:nil];
        });
    }
    else {
        NSLog(@"AutoFill has not been switched on!");
    }
}

- (IBAction)onSetupLater:(id)sender {
    [NSNotificationCenter.defaultCenter removeObserver:self];

    AppPreferences.sharedInstance.lastAskToEnableAutoFill = NSDate.date;
    
    self.onDone();
}

- (IBAction)onDontUse:(id)sender {
    [NSNotificationCenter.defaultCenter removeObserver:self];
    
    AppPreferences.sharedInstance.promptToEnableAutoFill = NO;
    
    self.onDone();
}

@end
