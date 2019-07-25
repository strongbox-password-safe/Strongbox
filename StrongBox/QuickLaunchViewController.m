//
//  QuickLaunchViewController.m
//  Strongbox-iOS
//
//  Created by Mark on 06/10/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
//

#import "QuickLaunchViewController.h"
#import "InitialViewController.h"
#import "Settings.h"
#import "Alerts.h"
#import "SafeMetaData.h"
#import "SafesList.h"
#import "BrowseSafeView.h"
#import "OpenSafeSequenceHelper.h"

@interface QuickLaunchViewController ()

@property (nonatomic, strong) CAGradientLayer *gradient;

@end

@implementation QuickLaunchViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.gradient = [CAGradientLayer layer];
    self.gradient.frame = self.view.bounds;
    
    UIColor *color1 = [UIColor colorWithRed:0.20 green:0.20 blue:0.40 alpha:1.0];
    UIColor *color2 = [UIColor colorWithRed:0.30 green:0.70 blue:0.80 alpha:1.0];

    //UIColor *color1 = [UIColor whiteColor];
    //UIColor *color2 = [UIColor blackColor];

    self.gradient.colors = @[(id)color1.CGColor, (id)color2.CGColor];

    [self.view.layer insertSublayer:self.gradient atIndex:0];
    
    //
    
    UITapGestureRecognizer *singleTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(openPrimarySafe)];
    singleTap.numberOfTapsRequired = 1;
    self.imageViewLogo.userInteractionEnabled = YES;
    [self.imageViewLogo addGestureRecognizer:singleTap];
    
    //
    
    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(onProStatusChanged:)
                                               name:kProStatusChangedNotificationKey
                                             object:nil];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    
    self.gradient.frame = self.view.bounds;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    [self.navigationController setNavigationBarHidden:YES];
    
    [self bindProOrFreeTrialUi];
    
    [[self getInitialViewController] checkICloudAvailability];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    [self refreshView];
}

- (void)onProStatusChanged:(id)param {
    NSLog(@"Pro Status Changed!");
    dispatch_async(dispatch_get_main_queue(), ^(void) {
        [self bindProOrFreeTrialUi];
    });
}

-(void)bindProOrFreeTrialUi {
    self.navigationController.toolbarHidden =  [[Settings sharedInstance] isPro];
    self.navigationController.toolbar.hidden = [[Settings sharedInstance] isPro];
    
    if(![[Settings sharedInstance] isPro]) {
        [self.buttonUpgrade setEnabled:YES];
        
        NSString *upgradeButtonTitle;
        if([[Settings sharedInstance] isFreeTrial]) {
            NSInteger daysLeft = [[Settings sharedInstance] getFreeTrialDaysRemaining];
            
            if(daysLeft > 30) {
                upgradeButtonTitle = @"Upgrade Info";
            }
            else {
                upgradeButtonTitle = [NSString stringWithFormat:@"Upgrade Info - (%ld Pro days left)",
                                  (long)daysLeft];
            }
            
            if(daysLeft < 10) {
                [self.buttonUpgrade setTintColor: [UIColor redColor]];
            }
        }
        else {
            upgradeButtonTitle = [NSString stringWithFormat:@"Please Upgrade..."];
            [self.buttonUpgrade setTintColor: [UIColor redColor]];
        }
        
        [self.buttonUpgrade setTitle:upgradeButtonTitle];
    }
    else {
        [self.buttonUpgrade setEnabled:NO];
        [self.buttonUpgrade setTintColor: [UIColor clearColor]];
    }
}

- (void)refreshView {
    SafeMetaData* primary = [[self getInitialViewController] getPrimarySafe];
    
    if(!primary) {
        [self switchToSafesListView];
    }
    else {
        self.labelSafeName.text = primary.nickName;
    }
}

- (InitialViewController *)getInitialViewController {
    InitialViewController *ivc = (InitialViewController*)self.navigationController.parentViewController;
    return ivc;
}

- (void)switchToSafesListView {
    Settings.sharedInstance.useQuickLaunchAsRootView = NO;
    
    [[self getInitialViewController] showSafesListView];
}

- (IBAction)onViewSafesList:(id)sender {
    [self switchToSafesListView];
}

- (IBAction)onOpenPrimarySafe:(id)sender {
    [self openPrimarySafe:NO];
}

- (void)openPrimarySafe {
    [self openPrimarySafe:NO];
}

- (void)openPrimarySafe:(BOOL)userJustCompletedBiometricAuthentication {
    // Only do this if we are top of the nav stack
    
    if(self.navigationController.topViewController != self) {
        NSLog(@"Not opening Primary safe as not at top of the Nav Stack");
        return;
    }
       
    SafeMetaData* safe = [[self getInitialViewController] getPrimarySafe];
    
    if(!safe) {
        [Alerts warn:self title:@"No Primary Database" message:@"Strongbox could not determine your primary database. Switch back to the Databases List View and ensure that there is at least one database present."];
        
        return;
    }
    
    [OpenSafeSequenceHelper beginSequenceWithViewController:self
                                                       safe:safe
                                        canConvenienceEnrol:YES
                                             isAutoFillOpen:NO
                                     manualOpenOfflineCache:NO
                                biometricAuthenticationDone:userJustCompletedBiometricAuthentication
                                                 completion:^(Model * _Nullable model, NSError * _Nullable error) {
        if(model) {
            if (@available(iOS 11.0, *)) { // iOS 11 required as only new Item Details is supported
                if(!Settings.sharedInstance.doNotUseNewSplitViewController) { // TODO: Eventually remove this preference
                    [self performSegueWithIdentifier:@"segueToMasterDetailFromQuick" sender:model];
                }
                else {
                    [self performSegueWithIdentifier:@"segueToBrowseFromQuick" sender:model];
                }
            }
            else {
                [self performSegueWithIdentifier:@"segueToBrowseFromQuick" sender:model];
            }
        }
                                                     
        [self refreshView]; // Duress might have removed the safe
    }];
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([segue.identifier isEqualToString:@"segueToBrowseFromQuick"]) {
        BrowseSafeView *vc = segue.destinationViewController;
        vc.viewModel = (Model *)sender;
        vc.currentGroup = vc.viewModel.database.rootGroup;
    }
    else if ([segue.identifier isEqualToString:@"segueToMasterDetailFromQuick"]) {
        UISplitViewController *svc = segue.destinationViewController;
        UINavigationController *nav = [svc.viewControllers firstObject];
        
        BrowseSafeView *vc = (BrowseSafeView*)nav.topViewController;
        vc.viewModel = (Model *)sender;
        vc.currentGroup = vc.viewModel.database.rootGroup;
    }
}

- (IBAction)onUpgrade:(id)sender {
    [self performSegueWithIdentifier:@"segueQuickLaunchToUpgrade" sender:nil];
}

@end
