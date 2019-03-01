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
#import "PickCredentialsTableViewController.h"

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
    
    if(primary && [[self getInitialViewController] autoFillIsPossibleWithSafe:primary]) {
        self.labelSafeName.text = primary.nickName;
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self openPrimarySafe];
        });
    }
}

- (void)refreshView {
    SafeMetaData* primary = [[self getInitialViewController] getPrimarySafe];
    
    if(primary && [[self getInitialViewController] autoFillIsPossibleWithSafe:primary]) {
        self.labelSafeName.text = primary.nickName;
    }
    else {
        self.labelSafeName.text = @"No Primary Database";
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
    
    if(!primary || ![[self getInitialViewController] autoFillIsPossibleWithSafe:primary]) {
        [self switchToSafesListView];
    }
    else {
        showWelcomeMessageIfAppropriate(self);
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
        [Alerts warn:self title:@"No Primary Database" message:@"Strongbox could not determine your primary database. Switch back to the Databases List View and ensure that there is at least one database present."];
        
        return;
    }

    BOOL useAutoFillCache = ![[self getInitialViewController] isLiveAutoFillProvider:safe.storageProvider];

    [OpenSafeSequenceHelper beginSequenceWithViewController:self
                                                       safe:safe
                                          openAutoFillCache:useAutoFillCache
                                          canConvenienceEnrol:NO
                                                 completion:^(Model * _Nonnull model) {
                                                     if(model) {
                                                         [self performSegueWithIdentifier:@"toPickCredentialsFromQuickLaunch" sender:model];
                                                     }
                                                     
                                                     [self refreshView];
                                                 }];
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([segue.identifier isEqualToString:@"toPickCredentialsFromQuickLaunch"]) {
        PickCredentialsTableViewController *vc = segue.destinationViewController;
        vc.model = (Model *)sender;
        vc.rootViewController = self.rootViewController;
    }
}

- (IBAction)onCancel:(id)sender {
    [[self getInitialViewController] cancel:nil];
}

@end
