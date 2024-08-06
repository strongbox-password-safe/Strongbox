//
//  TurnOnAutoFillViewController.m
//  Strongbox
//
//  Created by Strongbox on 18/08/2020.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import "TurnOnAutoFillViewController.h"
#import "AutoFillManager.h"
#import "DatabasePreferences.h"
#import "RoundedBlueButton.h"
#import "AppPreferences.h"
#import <AuthenticationServices/AuthenticationServices.h>

@interface TurnOnAutoFillViewController ()

@property (weak, nonatomic) IBOutlet UIButton *buttonDone;
@property (weak, nonatomic) IBOutlet RoundedBlueButton *buttonDontUse;
@property (weak, nonatomic) IBOutlet UIStackView *stackIOs17;
@property (weak, nonatomic) IBOutlet RoundedBlueButton *buttonIOS17;
@property (weak, nonatomic) IBOutlet UIStackView *stackOldInstructions;

@end

@implementation TurnOnAutoFillViewController

- (BOOL)shouldAutorotate {
    return UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad;
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad ? UIInterfaceOrientationMaskAll : UIInterfaceOrientationMaskPortrait;
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
    
    if ( @available(iOS 17.0, *) ) {
        self.buttonIOS17.hidden = NO;
        self.stackIOs17.hidden = NO;
        self.stackOldInstructions.hidden = YES;
    }
    else {
        self.buttonIOS17.hidden = YES;
        self.stackIOs17.hidden = YES;
        self.stackOldInstructions.hidden = NO;
    }
}

- (void)appBecameActive {
    if (AutoFillManager.sharedInstance.isOnForStrongbox) {
        slog(@"AutoFill has been switched on!");
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(.3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [NSNotificationCenter.defaultCenter removeObserver:self];            
            AppPreferences.sharedInstance.lastAskToEnableAutoFill = NSDate.date;
            self.onDone();
        });
    }
    else {
        slog(@"AutoFill has not been switched on!");
    }
}

- (IBAction)onSetupLater:(id)sender {
    [NSNotificationCenter.defaultCenter removeObserver:self];
    
    AppPreferences.sharedInstance.lastAskToEnableAutoFill = NSDate.date;
    
    self.onDone();
}

- (IBAction)onOpenAutoFillPreferences:(id)sender {
    if (@available(iOS 17.0, *)) {
        [ASSettingsHelper openCredentialProviderAppSettingsWithCompletionHandler:^(NSError * _Nullable error) {

        }];
    }
}

- (IBAction)onDontUse:(id)sender {
    [NSNotificationCenter.defaultCenter removeObserver:self];
    
    AppPreferences.sharedInstance.promptToEnableAutoFill = NO;
    
    self.onDone();
}

@end
