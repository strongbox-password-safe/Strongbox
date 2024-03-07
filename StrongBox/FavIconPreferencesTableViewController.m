//
//  FavIconPreferencesTableViewController.m
//  Strongbox-iOS
//
//  Created by Mark on 05/12/2019.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import "FavIconPreferencesTableViewController.h"
#import "Alerts.h"
#import "AppPreferences.h"
#import "Utils.h"

@interface FavIconPreferencesTableViewController ()

@property (weak, nonatomic) IBOutlet UISwitch *commonFiles;
@property (weak, nonatomic) IBOutlet UISwitch *duckDuckGo;
@property (weak, nonatomic) IBOutlet UISwitch *domainOnly;
@property (weak, nonatomic) IBOutlet UISwitch *google;
@property (weak, nonatomic) IBOutlet UISwitch *scanHtml;
@property (weak, nonatomic) IBOutlet UISwitch *ignoreSslErrors;

@property (weak, nonatomic) IBOutlet UISlider *sliderIdealSize;
@property (weak, nonatomic) IBOutlet UISlider *sliderMaxAutoSelectSize;
@property (weak, nonatomic) IBOutlet UISlider *sliderIdealDimensions;

@property (weak, nonatomic) IBOutlet UILabel *labelIdealSize;
@property (weak, nonatomic) IBOutlet UILabel *labelMaxSize;
@property (weak, nonatomic) IBOutlet UILabel *labelDimensions;
@property (weak, nonatomic) IBOutlet UITableViewCell *cellRestoreDefaults;

@end

@implementation FavIconPreferencesTableViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    [self bindUi];
}

- (void)bindUi {
    FavIconDownloadOptions* options = AppPreferences.sharedInstance.favIconDownloadOptions;
    
    self.commonFiles.on = options.checkCommonFavIconFiles;
    self.duckDuckGo.on = options.duckDuckGo;
    self.scanHtml.on = options.scanHtml;
    self.domainOnly.on = options.domainOnly;
    self.google.on = options.google;
    self.ignoreSslErrors.on = options.ignoreInvalidSSLCerts;
    
    self.labelDimensions.text = @(options.idealDimension).stringValue;
    self.labelIdealSize.text = @(options.idealSize / 1024).stringValue;
    self.labelMaxSize.text = @(options.maxSize / 1024).stringValue;
    
    self.sliderMaxAutoSelectSize.value = options.maxSize / 1024;
    self.sliderIdealSize.value = options.idealSize / 1024;
    self.sliderIdealDimensions.value = options.idealDimension;
}

- (IBAction)onSettingChanged:(id)sender {
    FavIconDownloadOptions* options = AppPreferences.sharedInstance.favIconDownloadOptions;
    
    options.checkCommonFavIconFiles = self.commonFiles.on;
    options.duckDuckGo = self.duckDuckGo.on;
    options.domainOnly = self.domainOnly.on;
    options.scanHtml = self.scanHtml.on;
    options.google = self.google.on;
    options.ignoreInvalidSSLCerts = self.ignoreSslErrors.on;
    
    if(options.isValid) {
        AppPreferences.sharedInstance.favIconDownloadOptions = options;
    }
    else {
        [Alerts warn:self
               title:NSLocalizedString(@"favicon_invalid_preferences_alert_title", @"Invalid FavIcon Settings")
             message:NSLocalizedString(@"favicon_invalid_preferences_alert_message", @"se settings will not produce valid FavIcon results.")];
    }
    
    [self bindUi];
}

- (IBAction)onSliderIdealSize:(id)sender {
    FavIconDownloadOptions* options = AppPreferences.sharedInstance.favIconDownloadOptions;

    options.idealSize = self.sliderIdealSize.value * 1024;

    AppPreferences.sharedInstance.favIconDownloadOptions = options;
    
    [self bindUi];
}

- (IBAction)onSliderIdealDimensions:(id)sender {
    FavIconDownloadOptions* options = AppPreferences.sharedInstance.favIconDownloadOptions;

    options.idealDimension = self.sliderIdealDimensions.value;

    AppPreferences.sharedInstance.favIconDownloadOptions = options;
    
    [self bindUi];
}

- (IBAction)onSliderMaxSize:(id)sender {
    FavIconDownloadOptions* options = AppPreferences.sharedInstance.favIconDownloadOptions;

    options.maxSize = self.sliderMaxAutoSelectSize.value * 1024;

    AppPreferences.sharedInstance.favIconDownloadOptions = options;
    
    [self bindUi];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell* cell = [self.tableView cellForRowAtIndexPath:indexPath];
    
    if ( cell == self.cellRestoreDefaults ) {
        [self restoreDefaults];
    }
    
    [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
}

- (void)restoreDefaults {
    AppPreferences.sharedInstance.favIconDownloadOptions = FavIconDownloadOptions.defaults;
    
    [self bindUi];
}

@end
