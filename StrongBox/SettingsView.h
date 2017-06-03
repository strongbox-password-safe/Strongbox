//
//  SettingsView.h
//  StrongBox
//
//  Created by Mark McGuill on 04/07/2014.
//  Copyright (c) 2014 Mark McGuill. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "GoogleDriveManager.h"

@interface SettingsView : UIViewController <UIActionSheetDelegate>

- (IBAction)onLongTouchCopy:(id)sender;
- (IBAction)onSignoutGoogleDrive:(id)sender;
- (IBAction)onAutoClose:(id)sender;
- (IBAction)onUnlinkDropbox:(id)sender;

@property (weak, nonatomic) IBOutlet UIButton *buttonLongTouchCopy;
@property (weak, nonatomic) IBOutlet UIButton *buttonAutoLock;
@property (weak, nonatomic) IBOutlet UIButton *buttonSignoutGoogleDrive;
@property (weak, nonatomic) IBOutlet UIButton *buttonUnlinkDropbox;
@property (weak, nonatomic) IBOutlet UIButton *buttonAbout;

@end
