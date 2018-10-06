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

@implementation QuickLaunchViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    CAGradientLayer *gradient = [CAGradientLayer layer];
    
    gradient.frame = self.view.bounds;
    
    UIColor *color1 = [UIColor colorWithRed:0.20 green:0.20 blue:0.40 alpha:1.0];
    UIColor *color2 = [UIColor colorWithRed:0.30 green:0.70 blue:0.80 alpha:1.0];

    //UIColor *color1 = [UIColor whiteColor];
    //UIColor *color2 = [UIColor blackColor];

    gradient.colors = @[(id)color1.CGColor, (id)color2.CGColor];

    [self.view.layer insertSublayer:gradient atIndex:0];
    
    //
    
    UITapGestureRecognizer *singleTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(openPrimarySafe)];
    singleTap.numberOfTapsRequired = 1;
    self.imageViewLogo.userInteractionEnabled = YES;
    [self.imageViewLogo addGestureRecognizer:singleTap];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    self.navigationController.toolbarHidden = YES;
    self.navigationController.toolbar.hidden = YES;
    [self.navigationController setNavigationBarHidden:YES];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];

    SafeMetaData* primary = [self getPrimarySafe];
    
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
    [self openPrimarySafe];
}

- (void)openPrimarySafe {
    SafeMetaData* safe = [self getPrimarySafe];
    
    if(!safe) {
        [Alerts warn:self title:@"No Primary Safe" message:@"Strongbox could not determine your primary safe. Switch back to the Safes List View and ensure that there is at least one safe present."];
        
        return;
    }
    
    NSLog(@"Primary Safe: [%@]", safe);
    
    if(safe.hasUnresolvedConflicts) {
        [Alerts warn:self title:@"Safe has Conflicts" message:@"This safe has unresolved conflicts. Please switch back to Safes List View and resolve these before opening."];
    }
    
    [[self getInitialViewController] beginOpenSafeSequence:safe completion:^(Model * _Nonnull model) {
        if(model) {
            [self performSegueWithIdentifier:@"segueToBrowseFromQuick" sender:model];
        }
    }];
}

- (SafeMetaData*)getPrimarySafe {
    SafeMetaData* safe = [SafesList.sharedInstance.snapshot firstObject];

    return safe;
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([segue.identifier isEqualToString:@"segueToBrowseFromQuick"]) {
        BrowseSafeView *vc = segue.destinationViewController;
        vc.viewModel = (Model *)sender;
        vc.currentGroup = vc.viewModel.rootGroup;
    }
}


@end
