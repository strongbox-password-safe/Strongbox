//
//  PasswordSettingsTableViewController.m
//  StrongBox
//
//  Created by Mark on 29/05/2017.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import "PasswordHistoryViewController.h"
#import "PreviousPasswordsTableViewController.h"
#import "Alerts.h"
//#import "Settings.h"

@interface PasswordHistoryViewController()

@property (strong, nonatomic) UILongPressGestureRecognizer *longPressRecognizer;

@end

@implementation PasswordHistoryViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self bindToModel];
}

-(void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];

    self.navigationController.navigationBar.hidden = NO;
    [self.navigationController setNavigationBarHidden:NO animated:YES];
}

-(void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
}

- (IBAction)onMaxEntriesStepper:(id)sender {
    _model.maximumSize = (int)self.uiStepper.value;

    [self save];
    [self bindToModel];
}

- (IBAction)onTogglePasswordHistoryEnabled:(id)sender {
    if (!self.uiSwitchEnabled.on && (_model.entries).count > 0) {
        [Alerts yesNo:self
                title:NSLocalizedString(@"pw_history_vc_prompt_disable_history_title", @"Disable History?")
              message:NSLocalizedString(@"pw_history_vc_prompt_disable_history_message", @"Are you sure you want to disable history? This will clear previous passwords.")
               action:^(BOOL response) {
                   if (response) {
                       self.model.enabled = NO;
                       [self.model.entries removeAllObjects];

                       [self save];
                       [self bindToModel];
                   }
                   else {
                       self.model.enabled = YES;
                       [self bindToModel];
                   }
               }];
    }
    else {
        self.model.enabled = self.uiSwitchEnabled.on;
        [self save];
        [self bindToModel];
    }
}

- (void)save {
    self.saveFunction(self.model);
}

- (void)bindToModel {    
    [self.uiSwitchEnabled setEnabled:!self.readOnly];
    self.uiSwitchEnabled.on = _model.enabled;

    self.uiTableViewCellMaximumEntries.userInteractionEnabled = !self.readOnly && _model.enabled;
    self.uiTableViewCellMaximumEntries.textLabel.enabled = _model.enabled;
    self.uiTableViewCellMaximumEntries.detailTextLabel.enabled = _model.enabled;

    self.uiTableViewCellPreviousPasswords.userInteractionEnabled = _model.enabled;
    self.uiTableViewCellPreviousPasswords.textLabel.enabled = _model.enabled;
    self.uiTableViewCellPreviousPasswords.detailTextLabel.enabled = _model.enabled;

    self.uiStepper.enabled = _model.enabled;
    self.uiStepper.value = _model.maximumSize;

    self.uiLabelMaximumEntriesStatic.enabled = _model.enabled;
    self.uiLabelMaximumEntries.enabled = _model.enabled;
    (self.uiLabelMaximumEntries).text = [NSString stringWithFormat:@"%lu", (unsigned long)_model.maximumSize];

    self.uiLabelPreviousPasswords.enabled = _model.enabled;

    if ((_model.entries).count > 0) {
        self.uiLabelPreviousPasswords.text = [NSString stringWithFormat:NSLocalizedString(@"pw_history_vc_previous_passwords_count_fmt", @"Old Passwords (%lu)"), (unsigned long)(_model.entries).count];
    }
    else {
        self.uiLabelPreviousPasswords.text = [NSString stringWithFormat:NSLocalizedString(@"pw_history_vc_previous_passwords_count_none", @"Old Passwords (None)")];
        self.uiLabelPreviousPasswords.enabled = NO;
        self.uiTableViewCellPreviousPasswords.userInteractionEnabled = NO;
        self.uiTableViewCellPreviousPasswords.textLabel.enabled = NO;
        self.uiTableViewCellPreviousPasswords.detailTextLabel.enabled = NO;
    }
}


- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([segue.identifier isEqual:@"segueToPreviousPasswords"]) {
        PreviousPasswordsTableViewController *vc = segue.destinationViewController;
        vc.model = _model;
    }
}

@end
