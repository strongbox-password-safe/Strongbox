//
//  PreferencesTableViewController.m
//  StrongBox
//
//  Created by Mark on 22/07/2017.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import "PreferencesTableViewController.h"
#import "Alerts.h"
#import "Utils.h"
#import "AppPreferences.h"
#import <MessageUI/MessageUI.h>
#import "DatabasePreferences.h"
#import "NSArray+Extensions.h"
#import "AutoFillManager.h"
#import "SelectItemTableViewController.h"
#import "AdvancedPreferencesTableViewController.h"
#import "DebugHelper.h"
#import "BiometricsManager.h"
#import "ClipboardManager.h"
#import "CustomizationManager.h"
#import "Strongbox-Swift.h"
#import "ProUpgradeIAPManager.h"
#import "Model.h"
#import "AppDelegate.h"

@interface PreferencesTableViewController () <MFMailComposeViewControllerDelegate>

@property (weak, nonatomic) IBOutlet UITableViewCell *cellAboutVersion;
@property (weak, nonatomic) IBOutlet UITableViewCell *cellAboutHelp;
@property (weak, nonatomic) IBOutlet UITableViewCell *cellPrivacyShield;
@property (weak, nonatomic) IBOutlet UITableViewCell *cellTipJar;
@property (weak, nonatomic) IBOutlet UITableViewCell *cellAppIcon;
@property (weak, nonatomic) IBOutlet UITableViewCell *cellContactSupport;

@property (weak, nonatomic) IBOutlet UILabel *labelVersion;
@property (weak, nonatomic) IBOutlet UILabel *labelProStatus;

@property (weak, nonatomic) IBOutlet UISwitch *switchShowTips;

@property (weak, nonatomic) IBOutlet UIImageView *imageViewTipJar;
@property (weak, nonatomic) IBOutlet UIImageView *imageViewAbout;
@property (weak, nonatomic) IBOutlet UIImageView *imageViewHelp;
@property (weak, nonatomic) IBOutlet UIImageView *imageViewAppIcon;
@property (weak, nonatomic) IBOutlet UIImageView *imageViewShowTips;
@property (weak, nonatomic) IBOutlet UIImageView *imageViewPrivacyShield;
@property (weak, nonatomic) IBOutlet UIImageView *imageViewAppLock;
@property (weak, nonatomic) IBOutlet UIImageView *imageViewAdvanced;
@property (weak, nonatomic) IBOutlet UIImageView *imageViewLicense;
@property (weak, nonatomic) IBOutlet UIImageView *imageViewContactSupport;
@property (weak, nonatomic) IBOutlet UIImageView *imageViewClipboard;
@property (weak, nonatomic) IBOutlet UITableViewCell *cellProStatus;

@property (weak, nonatomic) IBOutlet UITableViewCell *cellNoneCommercialUse;
@property (weak, nonatomic) IBOutlet UITableViewCell *cellAppAppearance;
@property (weak, nonatomic) IBOutlet UILabel *labelAppAppearance;
@property (weak, nonatomic) IBOutlet UILabel *labelPrivacyShieldMode;


@end

@implementation PreferencesTableViewController

- (IBAction)onDone:(id)sender {
    self.onDone();
}



- (void)viewDidLoad {
    [super viewDidLoad];

    [self customizeUI];
    
    [self bindVersionAndProStatus];
    [self bindHideTips];

    [self bindUI];
    
    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(onProStatusChanged:)
                                               name:kProStatusChangedNotification
                                             object:nil];
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self maybeRequestReview];
    });
}

- (void)bindUI {
    AppPreferences* prefs = AppPreferences.sharedInstance;
    self.labelAppAppearance.text = stringForAppAppearanceMode(prefs.appAppearance);
    self.labelPrivacyShieldMode.text = stringForPrivacyShieldMode(prefs.appPrivacyShieldMode);
}

- (void)onProStatusChanged:(id)param {
    dispatch_async(dispatch_get_main_queue(), ^(void) {
        [self bindVersionAndProStatus];
    });
}

- (void)customizeUI {
    if ( AppPreferences.sharedInstance.hideTipJar ) { 
        [self cell:self.cellTipJar setHidden:YES];
    }
    else {
        
        slog(@"Tips Loaded: [%hhd]", TipJarLogic.sharedInstance.isLoaded);
    }
    
    if ( !UIApplication.sharedApplication.supportsAlternateIcons ) {
        [self cell:self.cellAppIcon setHidden:YES];
    }
    
    
    
    self.imageViewAbout.image = [UIImage systemImageNamed:@"lock.shield"];
    self.imageViewTipJar.image = [UIImage systemImageNamed:@"gift"];
    self.imageViewTipJar.tintColor = UIColor.systemYellowColor;
    
    
    self.imageViewHelp.image = [UIImage systemImageNamed:@"questionmark.circle"];
    self.imageViewHelp.tintColor = UIColor.systemPurpleColor;
    self.imageViewAppIcon.image = [UIImage systemImageNamed:@"photo"];
    self.imageViewShowTips.image = [UIImage systemImageNamed:@"text.bubble"];

    self.imageViewPrivacyShield.image = [UIImage systemImageNamed:@"checkerboard.shield"];
    self.imageViewAppLock.image = [UIImage systemImageNamed:@"lock.circle"];
    self.imageViewAdvanced.image = [UIImage systemImageNamed:@"gear.circle"];

    BOOL licensed = AppPreferences.sharedInstance.isPro;
    NSString* license = licensed ? @"person.fill.checkmark" : @"person.fill.xmark";
    
    self.imageViewLicense.image =  [UIImage systemImageNamed:license];
    self.imageViewLicense.tintColor = licensed ? nil : UIColor.systemOrangeColor;

    if ( AppPreferences.sharedInstance.isPro ) {
        self.imageViewContactSupport.image =  [UIImage systemImageNamed:@"bubble.left"];
        self.imageViewContactSupport.tintColor = UIColor.systemPurpleColor;
        
        [self cell:self.cellNoneCommercialUse setHidden:YES];
    }
    else {
        [self cell:self.cellContactSupport setHidden:YES];
    }
    
    self.imageViewClipboard.image =  [UIImage systemImageNamed:@"doc.on.doc"];
    
    
    [self reloadDataAnimated:YES];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell* cell = [self.tableView cellForRowAtIndexPath:indexPath];
    [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    if ( cell == self.cellTipJar ) {
        [self performSegueWithIdentifier:@"segueToTipJar" sender:nil];
    }
    else if(cell == self.cellAboutHelp) {
        [self onHelp];
    }
    else if ( cell == self.cellPrivacyShield ) {
        NSArray<NSNumber*>* options = @[@(kAppPrivacyShieldModeNone),
                                        @(kAppPrivacyShieldModeBlur),
                                        @(kAppPrivacyShieldModePixellate),
                                        @(kAppPrivacyShieldModeBlueScreen),
                                        @(kAppPrivacyShieldModeBlackScreen),
                                        @(kAppPrivacyShieldModeDarkLogo),
                                        @(kAppPrivacyShieldModeRed),
                                        @(kAppPrivacyShieldModeGreen),
                                        @(kAppPrivacyShieldModeLightLogo),
                                        @(kAppPrivacyShieldModeWhite),
        ];
        
        NSArray<NSString*>* optionStrings = [options map:^id _Nonnull(NSNumber * _Nonnull obj, NSUInteger idx) {
            return stringForPrivacyShieldMode(obj.integerValue);
        }];
        
        [self promptForChoice:NSLocalizedString(@"prefs_vc_privacy_shield_view", @"Privacy Shield View")
                      options:optionStrings
         currentlySelectIndex:AppPreferences.sharedInstance.appPrivacyShieldMode
                   completion:^(BOOL success, NSInteger selectedIndex) {
            if ( success ) {
                AppPreferences.sharedInstance.appPrivacyShieldMode = selectedIndex;
                [self bindUI];
            }
        }];
    }
    else if ( cell == self.cellAppAppearance ) {
        NSArray<NSNumber*>* options = @[@(kAppAppearanceSystem),
                                        @(kAppAppearanceLight),
                                        @(kAppAppearanceDark)];
        
        NSArray<NSString*>* optionStrings = [options map:^id _Nonnull(NSNumber * _Nonnull obj, NSUInteger idx) {
            return stringForAppAppearanceMode(obj.integerValue);
        }];
        
        [self promptForChoice:NSLocalizedString(@"prefs_vc_app_appearance", @"App Appearance")
                      options:optionStrings
         currentlySelectIndex:AppPreferences.sharedInstance.appAppearance
                   completion:^(BOOL success, NSInteger selectedIndex) {
            if ( success ) {
                if ( selectedIndex != AppPreferences.sharedInstance.appAppearance ) {
                    AppPreferences.sharedInstance.appAppearance = selectedIndex;
                    
                    AppAppearance appearance = selectedIndex;
                    
                    if ( appearance == kAppAppearanceSystem ) {
                        UIApplication.sharedApplication.delegate.window.overrideUserInterfaceStyle = UIUserInterfaceStyleUnspecified;
                    }
                    else {
                        UIApplication.sharedApplication.delegate.window.overrideUserInterfaceStyle = appearance == kAppAppearanceLight ? UIUserInterfaceStyleLight : UIUserInterfaceStyleDark;
                    }
                    
                    [self bindUI];
                }
            }
        }];
    }
    else if ( cell == self.cellAppIcon ) {
        [self showAppIconCustomization];
    }
    else if ( cell == self.cellContactSupport ) {
        [self composeEmail];
    }
    else if ( cell == self.cellProStatus ) {
        [self showUpgradeScreenIfAppropriate];
    }
}

- (void)showAppIconCustomization {
    UINavigationController* vc = [CustomAppIconViewController fromStoryboard];
    
    [self presentViewController:vc animated:YES completion:nil];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

    [self.navigationController setNavigationBarHidden:NO];
}

- (void)showUpgradeScreenIfAppropriate {
    if ( CustomizationManager.isAProBundle || ( AppPreferences.sharedInstance.isPro && ProUpgradeIAPManager.sharedInstance.isLegacyLifetimeIAPPro )) {
        return;
    }
    
    [self performSegueWithIdentifier:@"segueToUpgradeScreen" sender:nil];
}

- (void)bindVersionAndProStatus {
    NSString *aboutString;
    
    if( AppPreferences.sharedInstance.isPro ) {
        aboutString = [NSString stringWithFormat:NSLocalizedString(@"about_strongbox_pro_version_fmt", @"Pro Version %@"), [Utils getAppVersion]];
    }
    else {
        aboutString = [NSString stringWithFormat:NSLocalizedString(@"about_strongbox_free_version_fmt", @"Version %@"), [Utils getAppVersion]];
    }
        
    self.labelVersion.text = aboutString;
        
    
    self.labelProStatus.textColor = UIColor.labelColor;
    self.cellProStatus.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    self.cellProStatus.selectionStyle = UITableViewCellSelectionStyleDefault;
    
    if ( CustomizationManager.isAProBundle ) {
        self.labelProStatus.text = NSLocalizedString(@"pro_status_lifetime_pro", @"Lifetime Pro");
        self.cellProStatus.accessoryType = UITableViewCellAccessoryNone;
        self.cellProStatus.selectionStyle = UITableViewCellSelectionStyleNone;
    }
    else {
        if ( AppPreferences.sharedInstance.isPro ) {
            if ( ProUpgradeIAPManager.sharedInstance.isLegacyLifetimeIAPPro ) { 
                self.labelProStatus.text = NSLocalizedString(@"pro_status_lifetime_pro_iap", @"Lifetime Pro (In-App Purchase)");
                self.cellProStatus.accessoryType = UITableViewCellAccessoryNone;
                self.cellProStatus.selectionStyle = UITableViewCellSelectionStyleNone;
            }
            else if ( ProUpgradeIAPManager.sharedInstance.hasActiveYearlySubscription ){
                self.labelProStatus.text = NSLocalizedString(@"pro_status_yearly_pro", @"Pro (Yearly subscription)");
            }
            else if ( ProUpgradeIAPManager.sharedInstance.hasActiveMonthlySubscription ) {
                self.labelProStatus.text = NSLocalizedString(@"pro_status_monthly_pro", @"Pro (Monthly subscription)");
            }
            else {
                self.labelProStatus.text = NSLocalizedString(@"pro_badge_text", @"Pro"); 
                self.cellProStatus.accessoryType = UITableViewCellAccessoryNone;
                self.cellProStatus.selectionStyle = UITableViewCellSelectionStyleNone;
            }
        }
        else {
            self.labelProStatus.text = NSLocalizedString(@"pro_status_unlicensed", @"Unlicensed");
        }
    }
    
    
    
    BOOL licensed = AppPreferences.sharedInstance.isPro;
    NSString* license = licensed ? @"person.fill.checkmark" : @"person.fill.xmark";
    self.imageViewLicense.image =  [UIImage systemImageNamed:license];
    self.imageViewLicense.tintColor = licensed ? nil : UIColor.systemOrangeColor;
    
    [self cell:self.cellContactSupport setHidden:!AppPreferences.sharedInstance.isPro];
}

- (void)bindHideTips {
    self.switchShowTips.on = !AppPreferences.sharedInstance.hideTips;
}

- (IBAction)onHideTips:(id)sender {
    AppPreferences.sharedInstance.hideTips = !self.switchShowTips.on;
    [self bindHideTips];
}


- (BOOL)hasLocalOrICloudSafes {
    return (DatabasePreferences.localDeviceDatabases.count + DatabasePreferences.iCloudDatabases.count) > 0;
}

- (void)onHelp {








        NSURL* url = [NSURL URLWithString:@"https:
        [UIApplication.sharedApplication openURL:url options:@{} completionHandler:nil];

}



static NSString* stringForPrivacyShieldMode(AppPrivacyShieldMode mode ){
    if ( mode == kAppPrivacyShieldModeBlur ) {
        return NSLocalizedString(@"app_privacy_shield_mode_blur", @"Blur");
    }
    else if (mode == kAppPrivacyShieldModePixellate ) {
        return NSLocalizedString(@"app_privacy_shield_mode_pixellate", @"Pixellate");
    }
    else if ( mode == kAppPrivacyShieldModeNone ) {
        return NSLocalizedString(@"privacy_shield_none", @"None"); 
    }
    else if ( mode == kAppPrivacyShieldModeBlueScreen ) {
        return NSLocalizedString(@"app_privacy_shield_mode_blue_screen", @"Blue Screen");
    }
    else if ( mode == kAppPrivacyShieldModeBlackScreen ) {
        return NSLocalizedString(@"app_privacy_shield_mode_black_screen", @"Black Screen");
    }
    else if ( mode == kAppPrivacyShieldModeDarkLogo ) {
        return NSLocalizedString(@"app_privacy_shield_mode_dark_logo", @"Dark Logo");
    }
    else if ( mode == kAppPrivacyShieldModeRed ) {
        return NSLocalizedString(@"app_privacy_shield_mode_red_screen", @"Red Screen");
    }
    else if ( mode == kAppPrivacyShieldModeGreen ) {
        return NSLocalizedString(@"app_privacy_shield_mode_green_screen", @"Green Screen");
    }
    else if ( mode == kAppPrivacyShieldModeLightLogo ) {
        return NSLocalizedString(@"app_privacy_shield_mode_blue_light_logo", @"Light Logo");
    }
    else if ( mode == kAppPrivacyShieldModeWhite ) {
        return NSLocalizedString(@"app_privacy_shield_mode_white_screen", @"White Screen");
    }
    else {
        return @"🔴 Error unknown privacy shield mode";
    }
}

static NSString* stringForAppAppearanceMode(AppAppearance mode ){
    if ( mode == kAppAppearanceSystem ) {
        return NSLocalizedString(@"app_appearance_mode_system", @"System");
    }
    else if (mode == kAppAppearanceLight ) {
        return NSLocalizedString(@"app_appearance_mode_light", @"Light");
    }
    else {
        return NSLocalizedString(@"app_appearance_mode_dark", @"Dark");
    }
}

- (void)promptForChoice:(NSString*)title
                options:(NSArray<NSString*>*)items
    currentlySelectIndex:(NSInteger)currentlySelectIndex
              completion:(void(^)(BOOL success, NSInteger selectedIndex))completion {
    UIStoryboard* storyboard = [UIStoryboard storyboardWithName:@"SelectItem" bundle:nil];
    UINavigationController* nav = (UINavigationController*)[storyboard instantiateInitialViewController];
    SelectItemTableViewController *vc = (SelectItemTableViewController*)nav.topViewController;

    vc.groupItems = @[items];
    
    if ( currentlySelectIndex != NSNotFound ) {
        vc.selectedIndexPaths = @[[NSIndexSet indexSetWithIndex:currentlySelectIndex]];
    }
    else {
        vc.selectedIndexPaths = nil;
    }
    
    vc.onSelectionChange = ^(NSArray<NSIndexSet *> * _Nonnull selectedIndices) {
        NSIndexSet* set = selectedIndices.firstObject;
        [self.navigationController popViewControllerAnimated:YES];
        completion(YES, set.firstIndex);
    };
    
    vc.title = title;
    [self.navigationController pushViewController:vc animated:YES];
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([segue.identifier isEqualToString:@"seguePrefsToAdvanced"]) {
        AdvancedPreferencesTableViewController* vc = (AdvancedPreferencesTableViewController*)segue.destinationViewController;
        vc.onDone = self.onDone;
    }
}




- (void)composeEmail {
    [DebugHelper getAboutDebugString:^(NSString * _Nonnull debugInfo) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self composeEmailWithDebugInfo:debugInfo];
        });
    }];
}

- (void)composeEmailWithDebugInfo:(NSString*)debugInfo {
    NSString* subject = @"Support Request";
    
    if(![MFMailComposeViewController canSendMail]) {
        NSString* str = [NSString stringWithFormat:@"mailto:support@strongboxsafe.com?subject=%@", [subject stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLHostAllowedCharacterSet]]];
        NSURL* url = [NSURL URLWithString:str];

        [UIApplication.sharedApplication openURL:url options:@{} completionHandler:^(BOOL success) {
            if (!success) {
                [Alerts info:self
                       title:NSLocalizedString(@"prefs_vc_info_email_not_available_title", @"Email Not Available")
                     message:NSLocalizedString(@"prefs_vc_info_email_not_available_message", @"It looks like email is not setup on this device.\n\nContact support@strongboxsafe.com for help.")];
            }
        }];
    }
    else {
        MFMailComposeViewController *picker = [[MFMailComposeViewController alloc] init];
        
        [picker setSubject:subject];
        [picker setToRecipients:@[@"support@strongboxsafe.com"]];
        [picker setMessageBody:[NSString stringWithFormat:@"<Please Include as much detail as possible about your issue here>\n\n\n------------------------------------\n%@", debugInfo] isHTML:NO];
        picker.mailComposeDelegate = self;
        
        [self presentViewController:picker animated:YES completion:^{ }];
    }
}

- (void)mailComposeController:(MFMailComposeViewController *)controller
          didFinishWithResult:(MFMailComposeResult)result
                        error:(NSError *)error {
    [self dismissViewControllerAnimated:YES completion:^{
        if(result == MFMailComposeResultFailed || error) {
            [Alerts error:self
                    title:NSLocalizedString(@"export_vc_email_error_sending", @"Error Sending")
                    error:error];
        }
    }];
}

- (void)maybeRequestReview {
    AppDelegate* appDelegate = (AppDelegate*)UIApplication.sharedApplication.delegate;
    
    NSTimeInterval timeDifference = [NSDate.date timeIntervalSinceDate:appDelegate.appLaunchTime];
    NSInteger launchCount = AppPreferences.sharedInstance.launchCount;

    double minutes = timeDifference / 60;

    
    
    if( minutes > 60 && launchCount > 45 ) {
#ifndef DEBUG
        [SKStoreReviewController requestReview];
#endif
    }
}

@end
