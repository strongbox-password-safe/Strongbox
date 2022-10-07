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
#import "PinEntryController.h"
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
    
    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(onProStatusChanged:)
                                               name:kProStatusChangedNotificationKey
                                             object:nil];
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self maybeRequestReview];
    });
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
        
        NSLog(@"Tips Loaded: [%hhd]", TipJarLogic.sharedInstance.isLoaded);
    }
    
    if ( !UIApplication.sharedApplication.supportsAlternateIcons ) {
        [self cell:self.cellAppIcon setHidden:YES];
    }
    
    
    
    if (@available(iOS 13.0, *)) {
        if (@available(iOS 15.0, *)) {
            self.imageViewAbout.image = [UIImage systemImageNamed:@"lock.shield"];
        }
        else {
            self.imageViewAbout.image = [UIImage systemImageNamed:@"lock.shield"];
        }
    } else {
        self.imageViewAbout.hidden = YES;
    }

    if (@available(iOS 13.0, *)) {
        self.imageViewTipJar.image = [UIImage systemImageNamed:@"gift"];
        self.imageViewTipJar.tintColor = UIColor.systemYellowColor;
    } else {
        self.imageViewTipJar.hidden = YES;
    }
    
    if (@available(iOS 13.0, *)) {
        self.imageViewHelp.image = [UIImage systemImageNamed:@"questionmark.circle"];

            self.imageViewHelp.tintColor = UIColor.systemPurpleColor;

    } else {
        self.imageViewHelp.hidden = YES;
    }
    
    if (@available(iOS 13.0, *)) {
        self.imageViewAppIcon.image = [UIImage systemImageNamed:@"photo"];
    } else {
        self.imageViewAppIcon.hidden = YES;
    }
    if (@available(iOS 13.0, *)) {
        self.imageViewShowTips.image = [UIImage systemImageNamed:@"text.bubble"];
    } else {
        self.imageViewShowTips.hidden = YES;
    }
    if (@available(iOS 13.0, *)) {
        if (@available(iOS 15.0, *)) {
            self.imageViewPrivacyShield.image = [UIImage systemImageNamed:@"checkerboard.shield"];
        }
        else {
            self.imageViewPrivacyShield.image = [UIImage systemImageNamed:@"shield"];
        }
    } else {
        self.imageViewPrivacyShield.hidden = YES;
    }
    
    if (@available(iOS 13.0, *)) {
        self.imageViewAppLock.image = [UIImage systemImageNamed:@"lock.circle"];
    } else {
        self.imageViewAppLock.hidden = YES;
    }

    if (@available(iOS 13.0, *)) {
        if (@available(iOS 15.0, *)) {
            self.imageViewAdvanced.image = [UIImage systemImageNamed:@"gear.circle"];
        }
        else {
            self.imageViewAdvanced.image = [UIImage systemImageNamed:@"gear"];
        }
    } else {
        self.imageViewAdvanced.hidden = YES;
    }

    if (@available(iOS 14.0, *)) {
        BOOL licensed = AppPreferences.sharedInstance.isPro;
        NSString* license = licensed ? @"person.fill.checkmark" : @"person.fill.xmark";
        
        self.imageViewLicense.image =  [UIImage systemImageNamed:license];
        self.imageViewLicense.tintColor = licensed ? nil : UIColor.systemOrangeColor;
    } else {
        self.imageViewLicense.hidden = YES;
    }

    if (@available(iOS 13.0, *)) {
        if ( AppPreferences.sharedInstance.isPro ) {
            self.imageViewContactSupport.image =  [UIImage systemImageNamed:@"bubble.left"];
            self.imageViewContactSupport.tintColor = UIColor.systemPurpleColor;
        }
        else {
            [self cell:self.cellContactSupport setHidden:YES];
        }

    } else {
        self.imageViewContactSupport.hidden = YES;
    }
    
    if (@available(iOS 13.0, *)) {
        self.imageViewClipboard.image =  [UIImage systemImageNamed:@"doc.on.doc"];
    } else {
        self.imageViewClipboard.hidden = YES;
    }
    
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
                                        @(kAppPrivacyShieldModeBlueScreen)];
        
        NSArray<NSString*>* optionStrings = [options map:^id _Nonnull(NSNumber * _Nonnull obj, NSUInteger idx) {
            return stringForPrivacyShieldMode(obj.integerValue);
        }];
        
        [self promptForChoice:NSLocalizedString(@"prefs_vc_privacy_shield_view", @"Privacy Shield View")
                      options:optionStrings
         currentlySelectIndex:AppPreferences.sharedInstance.appPrivacyShieldMode
                   completion:^(BOOL success, NSInteger selectedIndex) {
            if ( success ) {
                AppPreferences.sharedInstance.appPrivacyShieldMode = selectedIndex;
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
        
    if (@available(iOS 13.0, *)) {
        self.labelProStatus.textColor = UIColor.labelColor;
        self.cellProStatus.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        self.cellProStatus.selectionStyle = UITableViewCellSelectionStyleDefault;
    }
    
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
        else if ( AppPreferences.sharedInstance.isFreeTrial ) {
            self.labelProStatus.text = [NSString stringWithFormat:NSLocalizedString(@"pro_status_free_trial_days_left_fmt", @"Free Trial (%@ days left)"), @(AppPreferences.sharedInstance.freeTrialDaysLeft)];
        }
        else if ( AppPreferences.sharedInstance.hasOptedInToFreeTrial || AppPreferences.sharedInstance.daysInstalled > 60 ) {
            self.labelProStatus.text = NSLocalizedString(@"pro_status_unlicensed_please_upgrade", @"Unlicensed (Please Upgrade)");
            self.labelProStatus.textColor = UIColor.systemRedColor;
        }
        else {
            self.labelProStatus.text = NSLocalizedString(@"pro_status_unlicensed", @"Unlicensed");
        }
    }
    
    
    
    if (@available(iOS 14.0, *)) {
        BOOL licensed = AppPreferences.sharedInstance.isPro;
        NSString* license = licensed ? @"person.fill.checkmark" : @"person.fill.xmark";
        self.imageViewLicense.image =  [UIImage systemImageNamed:license];
        self.imageViewLicense.tintColor = licensed ? nil : UIColor.systemOrangeColor;
    }
    
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
        return NSLocalizedString(@"generic_none", @"None");
    }
    else {
        return NSLocalizedString(@"app_privacy_shield_mode_blue_screen", @"Blue Screen");
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
    NSString* debugInfo = [DebugHelper getAboutDebugString];
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
