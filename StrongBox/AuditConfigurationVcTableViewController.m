//
//  AuditConfigurationVcTableViewController.m
//  Strongbox
//
//  Created by Mark on 24/04/2020.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import "AuditConfigurationVcTableViewController.h"
#import "Alerts.h"
#import "Utils.h"
#import "SelectItemTableViewController.h"
#import "NSArray+Extensions.h"
#import "ExcludedItemsViewController.h"
#import "AppPreferences.h"
#import "NSDate+Extensions.h"
#import "DatabasePreferences.h"

static const int kSectionIdxHibp = 2; 
static const int kSectionIdxSimilarPasswords = 6; 

static const int kHibpAlwaysCheck = 0;
static const int kHibpOnceADay = 24 * 60 * 60;
static const int kHibpOnceAWeek = kHibpOnceADay * 7;
static const int kHibpOnceEvery30Days = kHibpOnceADay * 30;

@interface AuditConfigurationVcTableViewController ()

@property (weak, nonatomic) IBOutlet UISwitch *switchAuditInBackground;
@property (weak, nonatomic) IBOutlet UISwitch *switchNoPassword;
@property (weak, nonatomic) IBOutlet UISwitch *switchDuplicates;
@property (weak, nonatomic) IBOutlet UISwitch *switchCommon;
@property (weak, nonatomic) IBOutlet UISwitch *switchSimilar;
@property (weak, nonatomic) IBOutlet UISlider *sliderSimilar;
@property (weak, nonatomic) IBOutlet UILabel *labelSimilar;
@property (weak, nonatomic) IBOutlet UILabel *labelCheckSimilar;
@property (weak, nonatomic) IBOutlet UILabel *labelSimilarityThresholdTitle;
@property (weak, nonatomic) IBOutlet UILabel *labelStatus;
@property (weak, nonatomic) IBOutlet UISwitch *switchCaseInsenstiveDupes;

@property (weak, nonatomic) IBOutlet UISlider *sliderMinLength;
@property (weak, nonatomic) IBOutlet UILabel *minLengthLabel;
@property (weak, nonatomic) IBOutlet UISwitch *switchMinLength;
@property (weak, nonatomic) IBOutlet UILabel *statusSubtitle;

@property (weak, nonatomic) IBOutlet UISwitch *switchHibp;
@property (weak, nonatomic) IBOutlet UISwitch *switchShowPopups;

@property (weak, nonatomic) IBOutlet UITableViewCell *cellCheckHibp;
@property (weak, nonatomic) IBOutlet UITableViewCell *cellOnlineHibpInterval;

@property (weak, nonatomic) IBOutlet UILabel *labelOnlineCheckInterval;
@property (weak, nonatomic) IBOutlet UILabel *labelLastOnineCheck;
@property (weak, nonatomic) IBOutlet UILabel *labelLastChecked;
@property (weak, nonatomic) IBOutlet UILabel *labelLastOnlineCheckHeader;
@property (weak, nonatomic) IBOutlet UIStackView *stackViewLastOnlineCheck;
@property (weak, nonatomic) IBOutlet UILabel *labelCheckHaveIBeenPwned;

@property (weak, nonatomic) IBOutlet UILabel *labelCaseInsensitiveDupes;
@property (weak, nonatomic) IBOutlet UILabel *labelLengthOfMinimumLength;
@property (weak, nonatomic) IBOutlet UITableViewCell *cellViewExcluded;

@property (weak, nonatomic) IBOutlet UISwitch *switchLowEntropy;
@property (weak, nonatomic) IBOutlet UISlider *sliderEntropyThreshold;
@property (weak, nonatomic) IBOutlet UILabel *labelEntropyThreshold;
@property (weak, nonatomic) IBOutlet UILabel *labelLowEntropy;

@property (weak, nonatomic) IBOutlet UISwitch *switchTwoFactorAuth;
@property (weak, nonatomic) IBOutlet UISwitch *switchIgnorePINCodes;





@end

@implementation AuditConfigurationVcTableViewController

+ (instancetype)fromStoryboard {
    UIStoryboard* sb = [UIStoryboard storyboardWithName:@"Audit" bundle:nil];
    
    return [sb instantiateInitialViewController];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self cell:self.cellCheckHibp setHidden:AppPreferences.sharedInstance.disableNetworkBasedFeatures];
    [self cell:self.cellOnlineHibpInterval setHidden:AppPreferences.sharedInstance.disableNetworkBasedFeatures];
    
    [self reloadDataAnimated:NO];
    
    [self bindUi];
    
    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(bindAuditStatus:)
                                               name:kAuditProgressNotification
                                             object:nil];

    [NSNotificationCenter.defaultCenter addObserver:self
                                            selector:@selector(bindAuditStatus:)
                                                name:kAuditCompletedNotification
                                             object:nil];
}

- (void)bindUi {
    UIColor* secondary = UIColor.secondaryLabelColor;

    self.switchShowPopups.on = self.model.metadata.auditConfig.showAuditPopupNotifications;
    self.switchAuditInBackground.on = self.model.metadata.auditConfig.auditInBackground;
    
    
    
    self.switchNoPassword.on = self.model.metadata.auditConfig.checkForNoPasswords;
    self.switchCommon.on = self.model.metadata.auditConfig.checkForCommonPasswords;
    
    
    
    self.switchTwoFactorAuth.on = self.model.metadata.auditConfig.checkForTwoFactorAvailable;
    
    
    
    self.switchDuplicates.on = self.model.metadata.auditConfig.checkForDuplicatedPasswords;
    self.switchCaseInsenstiveDupes.on = self.model.metadata.auditConfig.caseInsensitiveMatchForDuplicates;
    self.switchCaseInsenstiveDupes.enabled = self.switchDuplicates.on;
    self.labelCaseInsensitiveDupes.textColor = self.switchDuplicates.on ? nil : secondary;
    
    
    
    self.switchSimilar.on = self.model.metadata.auditConfig.checkForSimilarPasswords;
    int sim = self.model.metadata.auditConfig.levenshteinSimilarityThreshold * 100.0f;
    self.labelSimilar.text = [NSString stringWithFormat:@"%d%%", sim];
    self.sliderSimilar.value = sim;
    
    
    
    self.switchMinLength.on = self.model.metadata.auditConfig.checkForMinimumLength;
    self.sliderMinLength.value = self.model.metadata.auditConfig.minimumLength;
    self.minLengthLabel.text = [NSString stringWithFormat:@"%lu", (unsigned long)self.model.metadata.auditConfig.minimumLength];
    self.sliderMinLength.enabled = self.model.metadata.auditConfig.checkForMinimumLength;
    self.labelLengthOfMinimumLength.textColor = self.switchMinLength.on ? nil : secondary;
    self.minLengthLabel.textColor = self.switchMinLength.on ? nil : secondary;
    
    
    
    self.switchHibp.on = self.model.metadata.auditConfig.checkHibp;

    [self bindLastOnlineCheckUi];
    self.cellOnlineHibpInterval.userInteractionEnabled = self.switchHibp.on;

    
    
    BOOL pro = AppPreferences.sharedInstance.isPro;
    self.switchHibp.enabled = pro;

    self.labelCheckHaveIBeenPwned.textColor = pro ? nil : secondary;
    self.labelLastOnlineCheckHeader.textColor = pro && self.switchHibp.on ? nil : secondary;
    self.labelOnlineCheckInterval.textColor = pro && self.switchHibp.on ? nil : secondary;

    self.labelCheckHaveIBeenPwned.textColor = pro ? nil : secondary;

    

    self.switchSimilar.enabled = pro;
    self.sliderSimilar.enabled = pro && self.switchSimilar.on;
    self.labelSimilar.textColor = pro && self.switchSimilar.on ? nil : secondary;
    self.labelSimilarityThresholdTitle.textColor = pro && self.switchSimilar.on ? nil : secondary;
    self.labelCheckSimilar.textColor = pro ? nil : secondary;

    
    
    self.switchLowEntropy.on = self.model.metadata.auditConfig.checkForLowEntropy;
    
    self.sliderEntropyThreshold.enabled = self.switchLowEntropy.on;
    self.labelLowEntropy.textColor = self.switchLowEntropy.on ? nil : secondary;
    self.labelEntropyThreshold.textColor = self.switchLowEntropy.on ? nil : secondary;
    
    self.sliderEntropyThreshold.value = self.model.metadata.auditConfig.lowEntropyThreshold;
    self.labelEntropyThreshold.text = [NSString stringWithFormat:@"%0.1f", (double)self.model.metadata.auditConfig.lowEntropyThreshold];

    
    
    self.switchIgnorePINCodes.on = self.model.metadata.auditConfig.excludeShortNumericPINCodes;

    
    
    [self bindAuditStatusWithProgress:nil];
}

- (void)bindLastOnlineCheckUi {
    self.labelOnlineCheckInterval.text = [self getHibpIntervalString:self.model.metadata.auditConfig.hibpCheckForNewBreachesIntervalSeconds];
    self.labelLastOnineCheck.text = self.model.metadata.auditConfig.lastHibpOnlineCheck ? self.model.metadata.auditConfig.lastHibpOnlineCheck.friendlyDateTimeString : @"";
    self.stackViewLastOnlineCheck.hidden = self.model.metadata.auditConfig.lastHibpOnlineCheck == nil;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if(section == kSectionIdxHibp && !AppPreferences.sharedInstance.isPro) {
        return NSLocalizedString(@"audit_hibp_pro_only_title", @"Have I Been Pwned? (Pro Edition Only)");
    }
    
    if(section == kSectionIdxSimilarPasswords && !AppPreferences.sharedInstance.isPro) {
        return NSLocalizedString(@"audit_similar_passwords_pro_only_title", @"Similar Passwords (Pro Edition Only");
    }

    return [super tableView:tableView titleForHeaderInSection:section];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell* cell = [tableView cellForRowAtIndexPath:indexPath];
    
    if (cell == self.cellOnlineHibpInterval) {
        [self onChangeOnlineHibpInterval];
    }
    else if (cell == self.cellViewExcluded) {
        [self performSegueWithIdentifier:@"segueToExcludedItems" sender:nil];
    }
}

- (void)onChangeOnlineHibpInterval {
    NSArray<NSNumber*>* opts = @[@(kHibpAlwaysCheck), @(kHibpOnceADay), @(kHibpOnceAWeek), @(kHibpOnceEvery30Days)];
    NSArray<NSString*>* options = [opts map:^id _Nonnull(NSNumber * _Nonnull obj, NSUInteger idx) {
        return [self getHibpIntervalString:obj.integerValue];
    }];
    
    NSUInteger idx = [opts indexOfObject:@(self.model.metadata.auditConfig.hibpCheckForNewBreachesIntervalSeconds)];
    
    NSString* loc = NSLocalizedString(@"audit_hibp_online_check_interval", @"Select Online Check Interval");
    
    [self promptForString:loc options:options currentIndex:idx completion:^(BOOL success, NSInteger selectedIdx) {
        NSNumber* sel = opts[selectedIdx];
        
        DatabaseAuditorConfiguration* config = self.model.metadata.auditConfig;
        config.hibpCheckForNewBreachesIntervalSeconds = sel.integerValue;
        self.model.metadata.auditConfig = config;
        
        [self bindUi];
    }];
}

- (void)bindAuditStatus:(NSNotification*)notification {
    if (notification.name == kAuditProgressNotification ) {
        [self bindAuditStatusWithProgress:notification.object];
    }
    else {

        [self bindAuditStatusWithProgress:nil];
    }
}

- (void)bindAuditStatusWithProgress:(NSNumber*)progress {
    switch (self.model.auditState) {
        case kAuditStateDone:
        {
            self.labelStatus.text = NSLocalizedString(@"audit_status_complete", @"Status: Complete");
            self.statusSubtitle.hidden = NO;

            NSString *loc;
            if (self.model.auditHibpErrorCount > 0) {
                loc = NSLocalizedString(@"audit_status_done_with_hibp_errors_fmt", @"Found %@ issues in %@ entries (with %@ HIBP Errors)");
            }
            else {
                loc = (self.model.auditIssueCount != nil && self.model.auditIssueCount.intValue > 0) ?
                    NSLocalizedString(@"audit_status_fmt", @"Found %@ issues in %@ entries") : NSLocalizedString(@"audit_status_no_issues_found", @"No issues found");
            }
            
            [self bindLastOnlineCheckUi];
            
            self.statusSubtitle.text =  [NSString stringWithFormat:loc, self.model.auditIssueCount, @(self.model.auditIssueNodeCount), @(self.model.auditHibpErrorCount)];
        }
            break;
        case kAuditStateInitial:
            self.labelStatus.text = self.model.metadata.auditConfig.auditInBackground ? NSLocalizedString(@"audit_status_initialized", @"Database Auditor Initialized") : NSLocalizedString(@"audit_status_initialized_but_disabled", @"audit_status_initialized_but_disabled");
            self.statusSubtitle.hidden = YES;
            break;
        case kAuditStateRunning:
            self.labelStatus.text = progress != nil ? [NSString stringWithFormat:NSLocalizedString(@"audit_status_running_with_progress_fmt", @"Auditing... (%d%%)"), ((int)(progress.floatValue * 100.0))] : NSLocalizedString(@"audit_status_running_with_ellipsis", @"Auditing...");
            self.statusSubtitle.hidden = YES;
            break;
        case kAuditStateStoppedIncomplete:
            self.labelStatus.text = NSLocalizedString(@"audit_status_stopped", @"Audit Stopped");
            self.statusSubtitle.hidden = YES;
            break;
        default:
            break;
    }
    
    
    
    [self reloadDataAnimated:YES];
    


}

- (IBAction)onPreferenceChanged:(id)sender {
    DatabaseAuditorConfiguration* config = self.model.metadata.auditConfig;
        
    config.auditInBackground = self.switchAuditInBackground.on;
    config.checkForNoPasswords = self.switchNoPassword.on;
    config.checkForDuplicatedPasswords = self.switchDuplicates.on;
    config.caseInsensitiveMatchForDuplicates = self.switchCaseInsenstiveDupes.on;
    config.checkForCommonPasswords = self.switchCommon.on;
    config.checkForSimilarPasswords = self.switchSimilar.on;
    config.checkForMinimumLength = self.switchMinLength.on;
    config.minimumLength = self.sliderMinLength.value;
    config.levenshteinSimilarityThreshold = ((CGFloat)self.sliderSimilar.value / 100.0f);
    config.checkHibp = self.switchHibp.on;
    config.showAuditPopupNotifications = self.switchShowPopups.on;

    config.checkForLowEntropy = self.switchLowEntropy.on;
    config.lowEntropyThreshold = self.sliderEntropyThreshold.value;
    config.checkForTwoFactorAvailable = self.switchTwoFactorAuth.on;
    config.excludeShortNumericPINCodes = self.switchIgnorePINCodes.on;
    
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(restartBackgroundAudit) object:nil];
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(saveSettingsAndRestartBackgroundAudit:) object:nil];
    
    [self performSelector:@selector(saveSettingsAndRestartBackgroundAudit:) withObject:config afterDelay:0.25f];
    
    [self bindUi];
}

- (void)saveSettingsAndRestartBackgroundAudit:(id)object {
    DatabaseAuditorConfiguration* config = (DatabaseAuditorConfiguration*)object;
    self.model.metadata.auditConfig = config;

    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(restartBackgroundAudit) object:nil];
    [self performSelector:@selector(restartBackgroundAudit) withObject:nil afterDelay:0.25f];

    [self bindUi];
}

- (void)restartBackgroundAudit {
    [self.model restartBackgroundAudit];
    
    

    if ( self.model ) {
        [NSNotificationCenter.defaultCenter postNotificationName:kAuditCompletedNotification
                                                          object:@{ @"userStopped" : @(NO),
                                                                    @"model" : self.model }];
    }
}

- (IBAction)onHibpChanged:(id)sender {
    if (!self.switchHibp.on) {
        DatabaseAuditorConfiguration* config = self.model.metadata.auditConfig;
        config.lastHibpOnlineCheck = nil;
        self.model.metadata.auditConfig = config;
    }
    
    if (self.switchHibp.on && self.model.metadata.auditConfig.checkHibp == NO && !self.model.metadata.auditConfig.hibpCaveatAccepted) {
        NSString* loc1 = NSLocalizedString(@"audit_hibp_warning_title", @"HIBP Disclaimer");
        NSString* loc2 = NSLocalizedString(@"audit_hibp_warning_message", @"I understand that my passwords will be sent over the web (HTTPS) to the 'Have I Been Pwned?' password checking service (using k-anonymity) and that I fully consent to this functionality. I also absolve Strongbox, Mark McGuill and Phoebe Code Limited of all liabilty for using this feature.");
        NSString* locNo = NSLocalizedString(@"audit_hibp_warning_no", @"No, I don't want to use this feature");
        NSString* locYes = NSLocalizedString(@"audit_hibp_warning_yes", @"Yes, I understand and agree");
        
        [Alerts twoOptionsWithCancel:self title:loc1 message:loc2 defaultButtonText:locNo secondButtonText:locYes action:^(int response) {
            if (response == 1) { 
                DatabaseAuditorConfiguration* config = self.model.metadata.auditConfig;
                
                config.hibpCaveatAccepted = YES;
                self.model.metadata.auditConfig = config;
                
                [self onPreferenceChanged:nil];
            }
            else { 
                [self bindUi];
            }
        }];
    }
    else {
        [self onPreferenceChanged:nil];
    }
}

- (IBAction)onDone:(id)sender {
    [self.presentingViewController dismissViewControllerAnimated:YES completion:nil];
}

- (void)promptForString:(NSString*)title
                options:(NSArray<NSString*>*)options
           currentIndex:(NSInteger)currentIndex
             completion:(void(^)(BOOL success, NSInteger selectedIdx))completion {
    UIStoryboard* storyboard = [UIStoryboard storyboardWithName:@"SelectItem" bundle:nil];
    UINavigationController* nav = (UINavigationController*)[storyboard instantiateInitialViewController];
    SelectItemTableViewController *vc = (SelectItemTableViewController*)nav.topViewController;
    
    vc.groupItems = @[options];
    vc.selectedIndexPaths = currentIndex == NSNotFound ? @[NSIndexSet.indexSet] : @[[NSIndexSet indexSetWithIndex:currentIndex]];
    
    vc.onSelectionChange = ^(NSArray<NSIndexSet *> * _Nonnull selectedIndices) {
        NSIndexSet* set = selectedIndices.firstObject;
        [self.navigationController popViewControllerAnimated:YES];
        completion(YES, set.firstIndex);
    };
    vc.title = title;
    
    [self.navigationController pushViewController:vc animated:YES];
}

- (NSString*)getHibpIntervalString:(NSUInteger)interval {
    switch (interval) {
        case kHibpAlwaysCheck:
            return NSLocalizedString(@"hibp_check_interval_always_check", @"Always Check");
            break;
        case kHibpOnceADay:
            return NSLocalizedString(@"hibp_check_interval_once_a_day", @"Once a Day");
            break;
        case kHibpOnceAWeek:
            return NSLocalizedString(@"hibp_check_interval_once_a_week", @"Once a Week");
            break;
        case kHibpOnceEvery30Days:
            return NSLocalizedString(@"hibp_check_interval_once_every_30_days", @"Once Every 30 days");
            break;
        default:
            return NSLocalizedString(@"generic_unknown", @"Unknown");
            break;
    }
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([segue.identifier isEqualToString:@"segueToExcludedItems"]) {
        ExcludedItemsViewController* vc = segue.destinationViewController;
        vc.model = self.model;
        vc.updateDatabase = self.updateDatabase;
    }
}

@end
