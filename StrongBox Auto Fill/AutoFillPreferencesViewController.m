//
//  AutoFillPreferencesViewController.m
//  Strongbox
//
//  Created by Strongbox on 17/08/2020.
//  Copyright © 2020 Mark McGuill. All rights reserved.
//

#import "AutoFillPreferencesViewController.h"
#import "AutoFillSettings.h"

@interface AutoFillPreferencesViewController ()

@property (weak, nonatomic) IBOutlet UISwitch *autoProceed;
@property (weak, nonatomic) IBOutlet UISwitch *addServiceIds;
@property (weak, nonatomic) IBOutlet UISwitch *useHostOnlyUrl;
@property (weak, nonatomic) IBOutlet UISwitch *mainAppSyncReminder;

@end

@implementation AutoFillPreferencesViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    [self bind];
}

- (void)bind {
    self.autoProceed.on = AutoFillSettings.sharedInstance.autoProceedOnSingleMatch;
    self.addServiceIds.on = AutoFillSettings.sharedInstance.storeAutoFillServiceIdentifiersInNotes;
    self.useHostOnlyUrl.on = !AutoFillSettings.sharedInstance.useFullUrlAsURLSuggestion;
    self.mainAppSyncReminder.on = !AutoFillSettings.sharedInstance.dontNotifyToSwitchToMainAppForSync;
}

- (IBAction)onDone:(id)sender {
    [self.presentingViewController dismissViewControllerAnimated:YES completion:nil];
}

- (IBAction)onChanged:(id)sender {
    AutoFillSettings.sharedInstance.autoProceedOnSingleMatch = self.autoProceed.on;
    AutoFillSettings.sharedInstance.storeAutoFillServiceIdentifiersInNotes = self.addServiceIds.on;
    AutoFillSettings.sharedInstance.useFullUrlAsURLSuggestion = !self.useHostOnlyUrl.on;
    AutoFillSettings.sharedInstance.dontNotifyToSwitchToMainAppForSync = !self.mainAppSyncReminder.on;
    
    [self bind];
}

@end
