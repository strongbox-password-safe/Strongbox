//
//  SettingsView.m
//  StrongBox
//
//  Created by Mark McGuill on 04/07/2014.
//  Copyright (c) 2014 Mark McGuill. All rights reserved.
//

#import "SettingsView.h"
#import "Utils.h"
#import <ObjectiveDropboxOfficial/ObjectiveDropboxOfficial.h>
#import "Alerts.h"

@interface SettingsView ()

@end

@implementation SettingsView {
    NSDictionary *_autoLockList;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    _autoLockList = @{  @"Never":              @ - 1,
                        @"Immediately":        @0,
                        @"After 1 minute":     @60,
                        @"After 10 minutes":   @600 };
    
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    id seconds = [userDefaults objectForKey:@"autoLockTimeSeconds"];
    
    NSArray *keys = [_autoLockList allKeysForObject:seconds ? seconds : @60]; // Default 60
    
    NSString *key = keys[0];
    [self.buttonAutoLock setTitle:key forState:UIControlStateNormal];
    [self.buttonAutoLock setTitle:key forState:UIControlStateHighlighted];
    
    //
    
    NSNumber *copyPasswordOnLongPress = [userDefaults valueForKey:@"copyPasswordOnLongPress"];
    BOOL longTouchCopyEnabled = copyPasswordOnLongPress ? copyPasswordOnLongPress.boolValue : YES;
    
    NSString *title = longTouchCopyEnabled ? @"On" : @"Off";
    [self.buttonLongTouchCopy setTitle:title forState:UIControlStateNormal];
    [self.buttonLongTouchCopy setTitle:title forState:UIControlStateHighlighted];
    
    NSString *aboutString = [NSString stringWithFormat:@"About %@", [Utils getAppName]];
    [self.buttonAbout setTitle:aboutString forState:UIControlStateNormal];
    [self.buttonAbout setTitle:aboutString forState:UIControlStateHighlighted];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    self.buttonUnlinkDropbox.hidden = !DBClientsManager.authorizedClient;
    
    BOOL x = [[GoogleDriveManager sharedInstance] isAuthorized];
    self.buttonSignoutGoogleDrive.hidden = !x;
}

- (IBAction)onLongTouchCopy:(id)sender {
    CGRect rcButton = self.buttonLongTouchCopy.frame;
    CGRect rcSheet = CGRectMake(rcButton.origin.x + (rcButton.size.width / 2), rcButton.origin.y + rcButton.size.height, 1, 1);
    
    [Alerts actionSheet:self
                   rect:rcSheet
                  title:@"Long Touch Copies Password:"
           buttonTitles:@[@"On", @"Off"]
             completion:^(int response) {
                 if (response) {
                     BOOL longTouchCopyEnabled = (response == 1);
                     
                     NSLog(@"Setting longTouchCopyEnabled to %d", longTouchCopyEnabled);
                     
                     NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
                     [userDefaults setBool:longTouchCopyEnabled
                                    forKey:@"copyPasswordOnLongPress"];
                     [userDefaults synchronize];
                     
                     NSString *title = longTouchCopyEnabled ? @"On" : @"Off";
                     [self.buttonLongTouchCopy setTitle:title
                                               forState:UIControlStateNormal];
                     [self.buttonLongTouchCopy setTitle:title
                                               forState:UIControlStateHighlighted];
                 }
             }];
}

- (IBAction)onAutoClose:(id)sender {
    NSArray *keys = _autoLockList.allKeys;
    NSArray *sortedKeys = [keys sortedArrayUsingComparator:^NSComparisonResult (id a, id b) {
        NSString *first = _autoLockList[a];
        NSString *second = _autoLockList[b];
        return [first compare:second];
    }];
    
    CGRect rcButton = self.buttonAutoLock.frame;
    CGRect rcSheet = CGRectMake(rcButton.origin.x + (rcButton.size.width / 2), rcButton.origin.y + rcButton.size.height, 1, 1);
    
    [Alerts actionSheet:self
                   rect:rcSheet
                  title:@"Auto Lock Safe Time:"
           buttonTitles:sortedKeys
             completion:^(int response) {
                 if (response) {
                     NSString *key = sortedKeys[response - 1];
                     id seconds = _autoLockList[key];
                     
                     NSLog(@"Setting Auto Lock Time to %@ Seconds", seconds);
                     
                     NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
                     [userDefaults setObject:seconds
                                      forKey:@"autoLockTimeSeconds"];
                     [userDefaults synchronize];
                     
                     [self.buttonAutoLock setTitle:key
                                          forState:UIControlStateNormal];
                     [self.buttonAutoLock setTitle:key
                                          forState:UIControlStateHighlighted];
                 }
             }];
}

- (IBAction)onUnlinkDropbox:(id)sender {
    if (DBClientsManager.authorizedClient) {
        [Alerts yesNo:self
                title:@"Unlink Dropbox?"
              message:@"Are you sure you want to unlink StrongBox from Dropbox?"
               action:^(BOOL response) {
                   if (response) {
                       [DBClientsManager unlinkAndResetClients];
                       self.buttonUnlinkDropbox.hidden = YES;
                       
                       [Alerts info:self
                              title:@"Unlink Successful"
                            message:@"You have successfully unlinked StrongBox from Dropbox."];
                   }
               }];
    }
}

- (IBAction)onSignoutGoogleDrive:(id)sender {
    if ([[GoogleDriveManager sharedInstance] isAuthorized]) {
        [Alerts yesNo:self
                title:@"Sign Out of Google Drive?"
              message:@"Are you sure you want to sign out of Google Drive?"
               action:^(BOOL response) {
                   if (response) {
                       [[GoogleDriveManager sharedInstance] signout];
                       self.buttonSignoutGoogleDrive.hidden = YES;
                       
                       [Alerts info:self
                              title:@"Sign Out Successful"
                            message:@"You have been successfully been signed out of Google Drive."];
                   }
               }];
    }
}

@end
