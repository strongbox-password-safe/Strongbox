//
//  ItemDetailsPreferencesViewController.m
//  Strongbox-iOS
//
//  Created by Mark on 09/06/2019.
//  Copyright © 2019 Mark McGuill. All rights reserved.
//

#import "ItemDetailsPreferencesViewController.h"
#import "Settings.h"

@interface ItemDetailsPreferencesViewController ()

@property (weak, nonatomic) IBOutlet UISwitch *switchShowTotp;
@property (weak, nonatomic) IBOutlet UISwitch *switchAutoFavIcon;
@property (weak, nonatomic) IBOutlet UISwitch *switchShowPasswordOnDetails;
@property (weak, nonatomic) IBOutlet UISwitch *switchShowEmptyFields;
@property (weak, nonatomic) IBOutlet UISwitch *easyReadFontForAll;

@end

@implementation ItemDetailsPreferencesViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    [self bindPreferences];
}

- (IBAction)onDone:(id)sender {
    [self.presentingViewController dismissViewControllerAnimated:YES completion:nil];
}

- (IBAction)onPreferencesChanged:(id)sender {
    NSLog(@"Item Details Preferences Changed: [%@]", sender);
    
    Settings.sharedInstance.tryDownloadFavIconForNewRecord = self.switchAutoFavIcon.on;
    Settings.sharedInstance.showPasswordByDefaultOnEditScreen = self.switchShowPasswordOnDetails.on;
    Settings.sharedInstance.hideTotp = !self.switchShowTotp.on;
    Settings.sharedInstance.showEmptyFieldsInDetailsView = self.switchShowEmptyFields.on;
    Settings.sharedInstance.easyReadFontForAll = self.easyReadFontForAll.on;

    [self bindPreferences];
    self.onPreferencesChanged();
}

- (void)bindPreferences {
    self.switchAutoFavIcon.on = Settings.sharedInstance.tryDownloadFavIconForNewRecord;
    self.switchShowPasswordOnDetails.on = Settings.sharedInstance.showPasswordByDefaultOnEditScreen;
    self.switchShowTotp.on = !Settings.sharedInstance.hideTotp;
    self.switchShowEmptyFields.on = Settings.sharedInstance.showEmptyFieldsInDetailsView;
    self.easyReadFontForAll.on = Settings.sharedInstance.easyReadFontForAll;
}

@end
