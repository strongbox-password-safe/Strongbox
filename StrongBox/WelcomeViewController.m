//
//  WelcomeViewController.m
//  Strongbox-iOS
//
//  Created by Mark on 05/06/2019.
//  Copyright © 2019 Mark McGuill. All rights reserved.
//

#import "WelcomeViewController.h"
#import "WelcomeCreateDatabaseViewController.h"
#import "SafesList.h"

@interface WelcomeViewController ()

@property (weak, nonatomic) IBOutlet UILabel *labelHeading;
@property (weak, nonatomic) IBOutlet UILabel *labelMessage1;
@property (weak, nonatomic) IBOutlet UILabel *labelMessage2;
@property (weak, nonatomic) IBOutlet UIButton *buttonCreate;
@property (weak, nonatomic) IBOutlet UIButton *buttonAdd;
@property (weak, nonatomic) IBOutlet UIButton *buttonDismiss;

@end

@implementation WelcomeViewController

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
    
    [self setupUi];
    
    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(onDatabasesChanged)
                                               name:kDatabasesListChangedNotification
                                             object:nil];
}

- (void)onDatabasesChanged {
    NSInteger count = SafesList.sharedInstance.snapshot.count;
    [self.buttonAdd setTitle:count ? (count == 1 ? @"View Your Database" : @"View Your Databases") : @"Add Existing Database" forState:UIControlStateNormal];
}

- (void)setupUi {
    self.buttonCreate.layer.cornerRadius = 5.0f;
    self.buttonAdd.layer.cornerRadius = 5.0f;
}

- (IBAction)onDismiss:(id)sender {
    self.onDone(NO, nil);
}

- (IBAction)onCreate:(id)sender {
    [self performSegueWithIdentifier:@"segueToCreate" sender:nil];
}

- (IBAction)onAdd:(id)sender {
    NSInteger count = SafesList.sharedInstance.snapshot.count;
    self.onDone(count == 0, nil);
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if([segue.identifier isEqualToString:@"segueToCreate"]) {
        WelcomeCreateDatabaseViewController* vc = (WelcomeCreateDatabaseViewController*)segue.destinationViewController;
        
        vc.onDone = self.onDone;
    }
}

//if([Settings.sharedInstance getLaunchCount] == 1) {
//    [Alerts info:self title:@"Welcome!"
//         message:@"Hi, Welcome to Strongbox!\n\nI hope you will enjoy the app!\n-Mark"];
//}
//else if([Settings.sharedInstance getLaunchCount] > 5 || Settings.sharedInstance.daysInstalled > 6) {
//    if(![[Settings sharedInstance] isHavePromptedAboutFreeTrial]) {
//        [Alerts info:self title:@"Strongbox Pro"
//             message:@"Hi there!\nYou are currently using Strongbox Pro. You can evaluate this version over the next three months. I hope you like it.\n\nAfter this I would ask you to contribute to its development. If you choose not to support the app, you will then be transitioned to a little bit more limited version. You won't lose any of your databases or passwords.\n\nTo find out more you can tap the Upgrade button at anytime below. I hope you enjoy the app, and will choose to support it!\n-Mark"];
//
//        [[Settings sharedInstance] setHavePromptedAboutFreeTrial:YES];
//    }
//}

@end
