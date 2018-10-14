//
//  QuickViewController.m
//  Strongbox Auto Fill
//
//  Created by Mark on 11/10/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
//

#import "QuickViewController.h"
#import "SafeMetaData.h"
#import "SafesList.h"
#import "Settings.h"
#import "Alerts.h"
#import "OpenSafeSequenceHelper.h"
#import "CredentialProviderViewController.h"
#import <SVProgressHUD/SVProgressHUD.h>

@interface QuickViewController ()

@property (nonatomic, strong) CAGradientLayer *gradient;

@end

@implementation QuickViewController

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
    
    [SVProgressHUD setViewForExtension:self.view];
    
    SafeMetaData* primary = [[self getInitialViewController] getPrimarySafe];
    
    if(primary && ![[self getInitialViewController] isUnsupportedAutoFillProvider:primary.storageProvider]) {
        self.labelSafeName.text = primary.nickName;
        [self openPrimarySafe];
    }
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    
    self.gradient.frame = self.view.bounds;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    [self.navigationController setNavigationBarHidden:YES];

    [self.navigationController setToolbarHidden:NO];
    self.navigationController.toolbar.hidden = NO;
    self.navigationController.toolbarHidden = NO;

    SafeMetaData* primary = [[self getInitialViewController] getPrimarySafe];
    
    if(!primary || [[self getInitialViewController] isUnsupportedAutoFillProvider:primary.storageProvider]) {
        [self switchToSafesListView];
    }
}


- (CredentialProviderViewController *)getInitialViewController {
    return self.rootViewController; 
}

- (void)switchToSafesListView {
    [[self getInitialViewController] showSafesListView];
}

- (IBAction)onViewSafesList:(id)sender {
    [self switchToSafesListView];
}

- (IBAction)onOpenPrimarySafe:(id)sender {
    [self openPrimarySafe];
}

- (void)openPrimarySafe {
    SafeMetaData* safe = [[self getInitialViewController] getPrimarySafe];
    
    if(!safe) {
        [Alerts warn:self title:@"No Primary Safe" message:@"Strongbox could not determine your primary safe. Switch back to the Safes List View and ensure that there is at least one safe present."];
        
        return;
    }
    
    [OpenSafeSequenceHelper.sharedInstance beginOpenSafeSequence:self
                                                            safe:safe
                               askAboutTouchIdEnrolIfAppropriate:NO
                                                      completion:^(Model * _Nonnull model) {
        if(model) {
            [self performSegueWithIdentifier:@"toPickCredentials" sender:model];
        }
    }];
}

//- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
//    if ([segue.identifier isEqualToString:@"segueFromQuickToPickCredentials"]) {
//        CredentialProviderViewController *vc = segue.destinationViewController;
//        vc.viewModel = (Model *)sender;
//    }
//}

- (IBAction)onCancel:(id)sender {
    [[self getInitialViewController] cancel:nil];
}

@end
