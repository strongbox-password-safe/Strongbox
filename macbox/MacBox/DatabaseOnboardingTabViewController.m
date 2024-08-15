//
//  DatabaseOnboardingTabViewController.m
//  MacBox
//
//  Created by Strongbox on 21/11/2020.
//  Copyright © 2020 Mark McGuill. All rights reserved.
//

#import "DatabaseOnboardingTabViewController.h"
#import "OnboardingWelcomeViewController.h"
#import "DatabasesManager.h"
#import "NSArray+Extensions.h"
#import "Settings.h"
#import "BiometricIdHelper.h"
#import "AutoFillManager.h"

@implementation DatabaseOnboardingTabViewController

+ (instancetype)fromStoryboard {
    NSStoryboard* sb = [NSStoryboard storyboardWithName:@"DatabaseOnboarding" bundle:nil];
    DatabaseOnboardingTabViewController* vc = [sb instantiateInitialController];
    return vc;
}



+ (BOOL)shouldPromptForBiometricEnrol:(MacDatabasePreferences*)databaseMetadata {
    BOOL featureAvailable = Settings.sharedInstance.isPro;
    BOOL watchAvailable = BiometricIdHelper.sharedInstance.isWatchUnlockAvailable;
    BOOL touchAvailable = BiometricIdHelper.sharedInstance.isTouchIdUnlockAvailable;
    BOOL convenienceAvailable = watchAvailable || touchAvailable;
    BOOL convenienceIsPossible = convenienceAvailable && featureAvailable;
    
    BOOL shouldPromptForBiometricEnrol = convenienceIsPossible && !databaseMetadata.hasPromptedForTouchIdEnrol;
    
    return shouldPromptForBiometricEnrol;
}

+ (BOOL)shouldPromptForAutoFillEnrol:(MacDatabasePreferences*)databaseMetadata {
    BOOL featureAvailable = Settings.sharedInstance.isPro;
    
    BOOL shouldPromptForAutoFillEnrol = featureAvailable && !databaseMetadata.hasPromptedForAutoFillEnrol;
    
    return shouldPromptForAutoFillEnrol;
}

+ (BOOL)shouldShowOnboarding:(MacDatabasePreferences*)databaseMetadata {
    return [self shouldPromptForBiometricEnrol:databaseMetadata] || [self shouldPromptForAutoFillEnrol:databaseMetadata];
}



- (void)viewDidLoad {
    [super viewDidLoad];
  
    [self setSelectedTabViewItemIndex:0];
    
    NSTabViewItem* tab1 = self.tabViewItems[0];
  
    OnboardingWelcomeViewController* welcomeVc = (OnboardingWelcomeViewController*)tab1.viewController;
    
    BOOL showTouchId = [DatabaseOnboardingTabViewController shouldPromptForBiometricEnrol:self.viewModel.databaseMetadata];
    BOOL showAutoFill = [DatabaseOnboardingTabViewController shouldPromptForAutoFillEnrol:self.viewModel.databaseMetadata];
        
    BOOL hasAutoFillDatabase = [DatabasesManager.sharedInstance.snapshot anyMatch:^BOOL(DatabaseMetadata * _Nonnull obj) {
        return obj.autoFillEnabled;
    }];
        


    __weak DatabaseOnboardingTabViewController* weakSelf = self;






}

- (void)onWelcomeDone:(BOOL)shouldSetTouchID
        enableTouchID:(BOOL)enableTouchID
    shouldSetAutoFill:(BOOL)shouldSetAutoFill
       enableAutoFill:(BOOL)enableAutoFill {
    if ( shouldSetTouchID ) {
        self.viewModel.databaseMetadata. isTouchIdEnabled = enableTouchID;
        self.viewModel.databaseMetadata.isWatchUnlockEnabled = enableTouchID;
        
        if ( enableTouchID ) {
            self.viewModel.databaseMetadata.conveniencePasswordHasBeenStored = YES;
            self.viewModel.databaseMetadata.conveniencePassword = self.ckfs.password;
        }
        else {
            self.viewModel.databaseMetadata.conveniencePasswordHasBeenStored = NO;
            self.viewModel.databaseMetadata.conveniencePassword = nil;
        }
        
        self.viewModel.databaseMetadata.hasPromptedForTouchIdEnrol = YES;
    }
    
    if ( shouldSetAutoFill ) {
        [AutoFillManager.sharedInstance clearAutoFillQuickTypeDatabase];

        self.viewModel.databaseMetadata.autoFillEnabled = enableAutoFill;
        self.viewModel.databaseMetadata.quickTypeEnabled = enableAutoFill;

        if ( enableAutoFill ) {
            [self updateQuickTypeAutoFillDatabases];
        }
        
        [self.viewModel rebuildMapsAndCaches];
                
        self.viewModel.databaseMetadata.hasPromptedForAutoFillEnrol = YES;
    }
    
    [self.view.window.sheetParent endSheet:self.view.window];

}

- (void)updateQuickTypeAutoFillDatabases {
    [AutoFillManager.sharedInstance updateAutoFillQuickTypeDatabase:self.viewModel.commonModel clearFirst:NO];
}

- (void)viewWillAppear {
    [super viewWillAppear];
    
    [self.view.window center];
}

@end
