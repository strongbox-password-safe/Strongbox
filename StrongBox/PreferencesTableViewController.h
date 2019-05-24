//
//  PreferencesTableViewController.h
//  StrongBox
//
//  Created by Mark on 22/07/2017.
//  Copyright © 2017 Mark McGuill. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface PreferencesTableViewController : UITableViewController

- (IBAction)onUseICloud:(id)sender;
- (IBAction)onLongTouchCopy:(id)sender;
- (IBAction)onShowPasswordOnDetails:(id)sender;
- (IBAction)onSegmentAutoLockChanged:(id)sender;
- (IBAction)onAllowBiometric:(id)sender;
- (IBAction)onAutoAddNewLocalSafesChanged:(id)sender;

@property (weak, nonatomic) IBOutlet UISwitch *switchAllowPinCodeOpen;

@property (weak, nonatomic) IBOutlet UISwitch *switchAllowBiometric;
@property (weak, nonatomic) IBOutlet UISwitch *switchLongTouchCopy;
@property (weak, nonatomic) IBOutlet UISwitch *switchShowPasswordOnDetails;
@property (weak, nonatomic) IBOutlet UISwitch *switchAutoAddNewLocalSafes;

@property (weak, nonatomic) IBOutlet UILabel *labelAllowBiometric;

@property (weak, nonatomic) IBOutlet UILabel *labelUseICloud;
@property (weak, nonatomic) IBOutlet UISwitch *switchUseICloud;
@property (weak, nonatomic) IBOutlet UISegmentedControl *segmentAutoLock;

@property (weak, nonatomic) IBOutlet UISwitch *switchShowKeePass1BackupFolder;
@property (weak, nonatomic) IBOutlet UISwitch *switchHideTips;

@property (weak, nonatomic) IBOutlet UISwitch *switchHideTotp;
@property (weak, nonatomic) IBOutlet UISwitch *switchHideTotpAutoFill;
@property (weak, nonatomic) IBOutlet UISwitch *switchHideTotpBrowseView;
@property (weak, nonatomic) IBOutlet UISwitch *switchNoSortingKeePassInBrowse;

@end
