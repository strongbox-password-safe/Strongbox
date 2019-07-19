//
//  AdvancedPreferencesTableViewController.m
//  Strongbox-iOS
//
//  Created by Mark on 27/05/2019.
//  Copyright © 2019 Mark McGuill. All rights reserved.
//

#import "AdvancedPreferencesTableViewController.h"
#import "Settings.h"
#import "AutoFillManager.h"

@interface AdvancedPreferencesTableViewController ()

@property (weak, nonatomic) IBOutlet UISwitch *switchAutoDetectKeyFiles;
@property (weak, nonatomic) IBOutlet UISwitch *switchCopyTotpAutoFill;
@property (weak, nonatomic) IBOutlet UISwitch *instantPinUnlock;
@property (weak, nonatomic) IBOutlet UISwitch *switchHideTotpAutoFill;
@property (weak, nonatomic) IBOutlet UISwitch *switchHideKeyFileName;
@property (weak, nonatomic) IBOutlet UISwitch *switchShowAllFilesInKeyFilesLocal;
@property (weak, nonatomic) IBOutlet UISwitch *switchUseOldNonSplitView;
@property (weak, nonatomic) IBOutlet UISwitch *switchShowYubikeySecretWorkaround;

@end

@implementation AdvancedPreferencesTableViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    self.navigationController.toolbar.hidden = YES;
    self.navigationController.toolbarHidden = YES;
    
    if (@available(iOS 11.0, *)) {
        self.navigationController.navigationBar.prefersLargeTitles = NO;
    }
    
    self.navigationController.navigationBar.hidden = NO;
    [self.navigationItem setPrompt:nil];
    [self.navigationController setNavigationBarHidden:NO];
    
    self.tableView.tableFooterView = [UIView new];
    
    [self bindPreferences];
}

- (IBAction)onDone:(id)sender {
    self.onDone();
}

- (IBAction)onPreferencesChanged:(id)sender {
    NSLog(@"Advanced Preference Changed: [%@]", sender);
    
    Settings.sharedInstance.instantPinUnlocking = self.instantPinUnlock.on;
    Settings.sharedInstance.doNotAutoDetectKeyFiles = !self.switchAutoDetectKeyFiles.on;
    Settings.sharedInstance.hideTotpInAutoFill = self.switchHideTotpAutoFill.on;
    Settings.sharedInstance.doNotCopyOtpCodeOnAutoFillSelect = !self.switchCopyTotpAutoFill.on;
    Settings.sharedInstance.hideKeyFileOnUnlock = self.switchHideKeyFileName.on;
    Settings.sharedInstance.showAllFilesInLocalKeyFiles = self.switchShowAllFilesInKeyFilesLocal.on;
    Settings.sharedInstance.doNotUseNewSplitViewController = self.switchUseOldNonSplitView.on;
    Settings.sharedInstance.showYubikeySecretWorkaroundField = self.switchShowYubikeySecretWorkaround.on;
    
    [self bindPreferences];
}

- (void)bindPreferences {
    self.instantPinUnlock.on = Settings.sharedInstance.instantPinUnlocking;
    self.switchAutoDetectKeyFiles.on = !Settings.sharedInstance.doNotAutoDetectKeyFiles;
    self.switchHideTotpAutoFill.on = Settings.sharedInstance.hideTotpInAutoFill;
    self.switchCopyTotpAutoFill.on = !Settings.sharedInstance.doNotCopyOtpCodeOnAutoFillSelect;
    self.switchHideKeyFileName.on = Settings.sharedInstance.hideKeyFileOnUnlock;
    self.switchShowAllFilesInKeyFilesLocal.on = Settings.sharedInstance.showAllFilesInLocalKeyFiles;
    self.switchUseOldNonSplitView.on = Settings.sharedInstance.doNotUseNewSplitViewController;
    self.switchShowYubikeySecretWorkaround.on = Settings.sharedInstance.showYubikeySecretWorkaroundField;
}

@end
