//
//  ItemDetailsPreferencesViewController.m
//  Strongbox-iOS
//
//  Created by Mark on 09/06/2019.
//  Copyright © 2019 Mark McGuill. All rights reserved.
//

#import "ItemDetailsPreferencesViewController.h"
#import "SafesList.h"

@interface ItemDetailsPreferencesViewController ()

@property (weak, nonatomic) IBOutlet UISwitch *switchShowTotp;
@property (weak, nonatomic) IBOutlet UISwitch *switchAutoFavIcon;
@property (weak, nonatomic) IBOutlet UISwitch *switchShowPasswordOnDetails;
@property (weak, nonatomic) IBOutlet UISwitch *switchShowEmptyFields;
@property (weak, nonatomic) IBOutlet UISwitch *easyReadFontForAll;
@property (weak, nonatomic) IBOutlet UISwitch *switchShowTotpCustom;

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
    
    self.database.tryDownloadFavIconForNewRecord = self.switchAutoFavIcon.on;
    self.database.showPasswordByDefaultOnEditScreen = self.switchShowPasswordOnDetails.on;
    self.database.hideTotp = !self.switchShowTotp.on;
    self.database.showEmptyFieldsInDetailsView = self.switchShowEmptyFields.on;
    self.database.easyReadFontForAll = self.easyReadFontForAll.on;
    self.database.hideTotpCustomFieldsInViewMode = !self.switchShowTotpCustom.on;
    
    NSLog(@"easyReadFontForAll: %d", self.database.easyReadFontForAll);
    
    [SafesList.sharedInstance update:self.database];
    
    [self bindPreferences];
    self.onPreferencesChanged();
}

- (void)bindPreferences {
    self.switchAutoFavIcon.on = self.database.tryDownloadFavIconForNewRecord;
    self.switchShowPasswordOnDetails.on = self.database.showPasswordByDefaultOnEditScreen;
    self.switchShowTotp.on = !self.database.hideTotp;
    self.switchShowEmptyFields.on = self.database.showEmptyFieldsInDetailsView;
    self.easyReadFontForAll.on = self.database.easyReadFontForAll;
    self.switchShowTotpCustom.on = !self.database.hideTotpCustomFieldsInViewMode;

    NSLog(@"easyReadFontForAll: %d", self.database.easyReadFontForAll);
}

@end
