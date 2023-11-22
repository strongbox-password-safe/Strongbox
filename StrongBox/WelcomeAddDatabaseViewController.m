//
//  WelcomeViewController.m
//  Strongbox-iOS
//
//  Created by Mark on 05/06/2019.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import "WelcomeAddDatabaseViewController.h"
#import "WelcomeCreateDatabaseViewController.h"
#import "DatabasePreferences.h"
#import "AppPreferences.h"
#import "AutoFillManager.h"
#import "SafesList.h"

@interface WelcomeAddDatabaseViewController ()

@property (weak, nonatomic) IBOutlet UILabel *labelHeading;
@property (weak, nonatomic) IBOutlet UILabel *labelMessage1;
@property (weak, nonatomic) IBOutlet UILabel *labelMessage2;
@property (weak, nonatomic) IBOutlet UIButton *buttonCreate;
@property (weak, nonatomic) IBOutlet UIButton *buttonAdd;
@property (weak, nonatomic) IBOutlet UIButton *buttonDismiss;
@property (weak, nonatomic) IBOutlet UIImageView *imageView;

@end

@implementation WelcomeAddDatabaseViewController

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
    
    [self setupUi];

    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(onDatabasesChanged)
                                               name:kDatabasesListChangedNotification
                                             object:nil];
}

- (void)onDatabasesChanged {
    NSInteger count = DatabasePreferences.allDatabases.count;
    [self.buttonAdd setTitle:count ? (count == 1 ?
                                      NSLocalizedString(@"welcome_vc_view_database", @"View Your Database") :
                                      NSLocalizedString(@"welcome_vc_view_databases", @"View Your Databases")) :
                                            NSLocalizedString(@"welcome_vc_add_existing_database", @"Add Existing Database")
                    forState:UIControlStateNormal];
}

- (void)setupUi {
    self.buttonCreate.layer.cornerRadius = 5.0f;
    self.buttonAdd.layer.cornerRadius = 5.0f;
    self.imageView.image = [UIImage systemImageNamed:@"wand.and.stars"];
}

- (IBAction)onDismiss:(id)sender {
    self.onDone(NO, nil);
}

- (IBAction)onCreate:(id)sender {
    [self performSegueWithIdentifier:@"segueToCreate" sender:nil];
}

- (IBAction)onAdd:(id)sender {
    self.onDone(YES, nil);
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if([segue.identifier isEqualToString:@"segueToCreate"]) {
        WelcomeCreateDatabaseViewController* vc = (WelcomeCreateDatabaseViewController*)segue.destinationViewController;
        vc.onDone = self.onDone;
    }
}

@end
