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
- (IBAction)onSignoutGoogleDrive:(id)sender;
- (IBAction)onUnlinkDropbox:(id)sender;

- (IBAction)onLongTouchCopy:(id)sender;
- (IBAction)onShowPasswordOnDetails:(id)sender;
- (IBAction)onSegmentAutoLockChanged:(id)sender;
- (IBAction)onContactSupport:(id)sender;

@property (weak, nonatomic) IBOutlet UISwitch *switchLongTouchCopy;
@property (weak, nonatomic) IBOutlet UISwitch *switchShowPasswordOnDetails;
@property (weak, nonatomic) IBOutlet UIButton *buttonAbout;

@property (weak, nonatomic) IBOutlet UILabel *labelUseICloud;
@property (weak, nonatomic) IBOutlet UISwitch *switchUseICloud;
@property (weak, nonatomic) IBOutlet UIButton *buttonSignoutGoogleDrive;
@property (weak, nonatomic) IBOutlet UIButton *buttonUnlinkDropbox;
@property (weak, nonatomic) IBOutlet UISegmentedControl *segmentAutoLock;


@end
