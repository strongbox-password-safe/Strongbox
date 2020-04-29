//
//  AuditConfigurationVcTableViewController.m
//  Strongbox
//
//  Created by Mark on 24/04/2020.
//  Copyright © 2020 Mark McGuill. All rights reserved.
//

#import "AuditConfigurationVcTableViewController.h"
#import "Settings.h"

const int kSectionIdxSimilarPasswords = 4; // Careful if sections move around

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
    
    [self bindAuditStatusWithProgress:nil];
    
    if (Settings.sharedInstance.isProOrFreeTrial) {
        self.switchSimilar.enabled = YES;
        self.sliderSimilar.enabled = YES;
    }
    else {
        if (@available(iOS 13.0, *)) {
            self.labelSimilar.textColor = UIColor.secondaryLabelColor;
            self.labelCheckSimilar.textColor =  UIColor.secondaryLabelColor;
            self.labelSimilarityThresholdTitle.textColor =  UIColor.secondaryLabelColor;
        }
        else {
            self.labelSimilar.textColor = UIColor.darkGrayColor;
            self.labelCheckSimilar.textColor =  UIColor.darkGrayColor;
            self.labelSimilarityThresholdTitle.textColor =  UIColor.darkGrayColor;
        }
        self.switchSimilar.enabled = NO;
        self.sliderSimilar.enabled = NO;
    }
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if(section == kSectionIdxSimilarPasswords && !Settings.sharedInstance.isProOrFreeTrial) {
        return NSLocalizedString(@"audit_similar_passwords_pro_only_title", @"Similar Passwords (Pro Edition Only");
    }
    
    return [super tableView:tableView titleForHeaderInSection:section];
}

- (void)bindAuditStatus:(NSNotification*)notification {
    [self bindAuditStatusWithProgress:notification.object];
}

- (void)bindAuditStatusWithProgress:(NSNumber*)progress {
    switch (self.model.auditState) {
        case kAuditStateDone:
        {
            self.labelStatus.text = NSLocalizedString(@"audit_status_complete", @"Status: Complete");
         
            NSString *loc = self.model.auditIssueCount ?
                NSLocalizedString(@"audit_status_fmt", @"Found %@ issues in %@ entries") : NSLocalizedString(@"audit_status_no_issues_found", @"No issues found");
            
            self.statusSubtitle.hidden = NO;
            self.statusSubtitle.text =  [NSString stringWithFormat:loc, @(self.model.auditIssueCount), @(self.model.auditIssueNodeCount)];
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

- (IBAction)onDone:(id)sender {
    [self.presentingViewController dismissViewControllerAnimated:YES completion:nil];
}

@end
