//
//  AuditConfigurationVcTableViewController.m
//  Strongbox
//
//  Created by Mark on 24/04/2020.
//  Copyright © 2020 Mark McGuill. All rights reserved.
//

#import "AuditConfigurationVcTableViewController.h"
#import "Settings.h"
#import "Alerts.h"
#import "Utils.h"
#import "SelectItemTableViewController.h"
#import "NSArray+Extensions.h"

static const int kSectionIdxHibp = 2; // Careful if sections move around
static const int kSectionIdxSimilarPasswords = 5; // Careful if sections move around 

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

@property (weak, nonatomic) IBOutlet UITableViewCell *cellOnlineHibpInterval;

@property (weak, nonatomic) IBOutlet UILabel *labelOnlineCheckInterval;
@property (weak, nonatomic) IBOutlet UILabel *labelLastOnineCheck;
@property (weak, nonatomic) IBOutlet UILabel *labelLastChecked;
@property (weak, nonatomic) IBOutlet UILabel *labelLastOnlineCheckHeader;
@property (weak, nonatomic) IBOutlet UIStackView *stackViewLastOnlineCheck;
@property (weak, nonatomic) IBOutlet UILabel *labelCheckHaveIBeenPwned;

@end

@implementation AuditConfigurationVcTableViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    [self bindUi];
    
    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(bindAuditStatus:)
                                               name:kAuditProgressNotificationKey
                                             object:nil];

    [NSNotificationCenter.defaultCenter addObserver:self
                                            selector:@selector(bindAuditStatus:)
                                                name:kAuditCompletedNotificationKey
                                             object:nil];
}

- (void)bindUi {
    self.switchAuditInBackground.on = self.model.metadata.auditConfig.auditInBackground;
    self.switchNoPassword.on = self.model.metadata.auditConfig.checkForNoPasswords;
    self.switchDuplicates.on = self.model.metadata.auditConfig.checkForDuplicatedPasswords;
    self.switchCaseInsenstiveDupes.on = self.model.metadata.auditConfig.caseInsensitiveMatchForDuplicates;
    
    self.switchCommon.on = self.model.metadata.auditConfig.checkForCommonPasswords;
    self.switchSimilar.on = self.model.metadata.auditConfig.checkForSimilarPasswords;
    
    int sim = self.model.metadata.auditConfig.levenshteinSimilarityThreshold * 100.0f;
    self.labelSimilar.text = [NSString stringWithFormat:@"%d%%", sim];
    self.sliderSimilar.value = sim;
    self.sliderSimilar.enabled = self.model.metadata.auditConfig.checkForSimilarPasswords;
    
    self.switchMinLength.on = self.model.metadata.auditConfig.checkForMinimumLength;
    self.sliderMinLength.value = self.model.metadata.auditConfig.minimumLength;
    self.minLengthLabel.text = [NSString stringWithFormat:@"%lu", (unsigned long)self.model.metadata.auditConfig.minimumLength];
    self.sliderMinLength.enabled = self.model.metadata.auditConfig.checkForMinimumLength;

    self.switchShowPopups.on = self.model.metadata.auditConfig.showAuditPopupNotifications;

    self.switchHibp.on = self.model.metadata.auditConfig.checkHibp;
    
    [self bindLastOnlineCheckUi];
    
    if (self.switchHibp.on) {
        self.labelOnlineCheckInterval.textColor = nil;
        self.labelLastOnlineCheckHeader.textColor = nil;

        self.cellOnlineHibpInterval.userInteractionEnabled = YES;
    }
    else {
        if (@available(iOS 13.0, *)) {
            self.labelOnlineCheckInterval.textColor = UIColor.secondaryLabelColor;
            self.labelLastOnlineCheckHeader.textColor = UIColor.secondaryLabelColor;
        }
        else {
            self.labelOnlineCheckInterval.textColor = UIColor.darkGrayColor;
            self.labelLastOnlineCheckHeader.textColor = UIColor.darkGrayColor;
        }
        
        self.cellOnlineHibpInterval.userInteractionEnabled = NO;
    }
    
    [self bindAuditStatusWithProgress:nil];
    
    if (Settings.sharedInstance.isProOrFreeTrial) {
        self.switchSimilar.enabled = YES;
        self.sliderSimilar.enabled = YES;
        self.switchHibp.enabled = YES;
        
        self.labelOnlineCheckInterval.textColor = nil;
        self.labelLastOnlineCheckHeader.textColor = nil;
        self.labelCheckHaveIBeenPwned.textColor = nil;
    }
    else {
        if (@available(iOS 13.0, *)) {
            self.labelSimilar.textColor = UIColor.secondaryLabelColor;
            self.labelCheckSimilar.textColor =  UIColor.secondaryLabelColor;
            self.labelSimilarityThresholdTitle.textColor =  UIColor.secondaryLabelColor;
            
            self.labelOnlineCheckInterval.textColor = UIColor.secondaryLabelColor;
            self.labelLastOnlineCheckHeader.textColor = UIColor.secondaryLabelColor;
            self.labelCheckHaveIBeenPwned.textColor = UIColor.secondaryLabelColor;
        }
        else {
            self.labelSimilar.textColor = UIColor.darkGrayColor;
            self.labelCheckSimilar.textColor =  UIColor.darkGrayColor;
            self.labelSimilarityThresholdTitle.textColor =  UIColor.darkGrayColor;
            
            self.labelOnlineCheckInterval.textColor = UIColor.darkGrayColor;
            self.labelLastOnlineCheckHeader.textColor = UIColor.darkGrayColor;
            self.labelCheckHaveIBeenPwned.textColor = UIColor.darkGrayColor;
        }
        
        self.switchSimilar.enabled = NO;
        self.sliderSimilar.enabled = NO;
        self.switchHibp.enabled = NO;
    }
}

- (void)bindLastOnlineCheckUi {
    self.labelOnlineCheckInterval.text = [self getHibpIntervalString:self.model.metadata.auditConfig.hibpCheckForNewBreachesIntervalSeconds];
    self.labelLastOnineCheck.text = friendlyDateString(self.model.metadata.auditConfig.lastHibpOnlineCheck);
    self.stackViewLastOnlineCheck.hidden = self.model.metadata.auditConfig.lastHibpOnlineCheck == nil;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if(section == kSectionIdxHibp && !Settings.sharedInstance.isProOrFreeTrial) {
        return NSLocalizedString(@"audit_hibp_pro_only_title", @"Have I Been Pwned? (Pro Edition Only)");
    }
    
    if(section == kSectionIdxSimilarPasswords && !Settings.sharedInstance.isProOrFreeTrial) {
        return NSLocalizedString(@"audit_similar_passwords_pro_only_title", @"Similar Passwords (Pro Edition Only");
    }

    return [super tableView:tableView titleForHeaderInSection:section];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell* cell = [tableView cellForRowAtIndexPath:indexPath];
    
    if (cell == self.cellOnlineHibpInterval) {
        [self onChangeOnlineHibpInterval];
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
        self.model.metadata.auditConfig.hibpCheckForNewBreachesIntervalSeconds = sel.integerValue;
        [SafesList.sharedInstance update:self.model.metadata];
        [self bindUi];
    }];
}

- (void)bindAuditStatus:(NSNotification*)notification {
    [self bindAuditStatusWithProgress:notification.object];
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
                loc = self.model.auditIssueCount ?
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
            self.labelStatus.text = progress ? [NSString stringWithFormat:NSLocalizedString(@"audit_status_running_with_progress_fmt", @"Auditing... (%d%%)"), ((int)(progress.floatValue * 100.0))] : NSLocalizedString(@"audit_status_running_with_ellipsis", @"Auditing...");
            self.statusSubtitle.hidden = YES;
            break;
        case kAuditStateStoppedIncomplete:
            self.labelStatus.text = NSLocalizedString(@"audit_status_stopped", @"Audit Stopped");
            self.statusSubtitle.hidden = YES;
            break;
        default:
            break;
    }
    
    // Resize Cells
    [self.tableView beginUpdates];
    [self.tableView endUpdates];
}

- (IBAction)onPreferenceChanged:(id)sender {    
    self.model.metadata.auditConfig.auditInBackground = self.switchAuditInBackground.on;
    self.model.metadata.auditConfig.checkForNoPasswords = self.switchNoPassword.on;
    self.model.metadata.auditConfig.checkForDuplicatedPasswords = self.switchDuplicates.on;
    self.model.metadata.auditConfig.caseInsensitiveMatchForDuplicates = self.switchCaseInsenstiveDupes.on;
    
    self.model.metadata.auditConfig.checkForCommonPasswords = self.switchCommon.on;
    self.model.metadata.auditConfig.checkForSimilarPasswords = self.switchSimilar.on;

    self.model.metadata.auditConfig.checkForMinimumLength = self.switchMinLength.on;
    self.model.metadata.auditConfig.minimumLength = self.sliderMinLength.value;
    
    self.model.metadata.auditConfig.levenshteinSimilarityThreshold = ((CGFloat)self.sliderSimilar.value / 100.0f);
        
    self.model.metadata.auditConfig.checkHibp = self.switchHibp.on;
    self.model.metadata.auditConfig.showAuditPopupNotifications = self.switchShowPopups.on;
    
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(restartBackgroundAudit) object:nil];
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(saveSettingsAndRestartBackgroundAudit) object:nil];
    
    [self performSelector:@selector(saveSettingsAndRestartBackgroundAudit) withObject:nil afterDelay:0.25f];
    
    [self.model stopAndClearAuditor];
    
    [self bindUi];
}

- (void)saveSettingsAndRestartBackgroundAudit {
    [SafesList.sharedInstance update:self.model.metadata];

    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(restartBackgroundAudit) object:nil];
    [self performSelector:@selector(restartBackgroundAudit) withObject:nil afterDelay:0.25f];

    [self bindUi];
}

- (void)restartBackgroundAudit {
    [self.model restartBackgroundAudit];
}

- (IBAction)onHibpChanged:(id)sender {
    if (!self.switchHibp.on) {
        self.model.metadata.auditConfig.lastHibpOnlineCheck = nil;
        [SafesList.sharedInstance update:self.model.metadata];
    }
    
    if (self.switchHibp.on && self.model.metadata.auditConfig.checkHibp == NO && !self.model.metadata.auditConfig.hibpCaveatAccepted) {
        NSString* loc1 = NSLocalizedString(@"audit_hibp_warning_title", @"HIBP Disclaimer");
        NSString* loc2 = NSLocalizedString(@"audit_hibp_warning_message", @"I understand that my passwords will be sent over the web (HTTPS) to the 'Have I Been Pwned?' password checking service (using k-anonymity) and that I fully consent to this functionality. I also absolve Strongbox, Mark McGuill and Phoebe Code Limited of all liabilty for using this feature.");
        NSString* locNo = NSLocalizedString(@"audit_hibp_warning_no", @"No, I don't want to use this feature");
        NSString* locYes = NSLocalizedString(@"audit_hibp_warning_yes", @"Yes, I understand and agree");
        
        [Alerts twoOptionsWithCancel:self title:loc1 message:loc2 defaultButtonText:locNo secondButtonText:locYes action:^(int response) {
            if (response == 1) { // Yes go for it
                self.model.metadata.auditConfig.hibpCaveatAccepted = YES;
                [SafesList.sharedInstance update:self.model.metadata];
                
                [self onPreferenceChanged:nil];
            }
            else { // No or cancel
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

@end
