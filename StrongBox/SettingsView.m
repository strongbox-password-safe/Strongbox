//
//  SettingsView.m
//  StrongBox
//
//  Created by Mark McGuill on 04/07/2014.
//  Copyright (c) 2014 Mark McGuill. All rights reserved.
//

#import "SettingsView.h"
#import <DropboxSDK/DropboxSDK.h>
#import "core-model/Utils.h"

@interface SettingsView ()

@end

@implementation SettingsView
{
    NSDictionary *_autoLockList;
}

-(void) viewDidLoad
{
    [super viewDidLoad];
    
    _autoLockList = @{  @"Never" :              @-1,
                        @"Immediately" :        @0,
                        @"After 1 minute" :     @60,
                        @"After 10 minutes" :   @600};
    
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    id seconds = [userDefaults objectForKey:@"autoLockTimeSeconds"];
    
    NSArray *keys = [_autoLockList allKeysForObject:seconds ? seconds : @60]; // Default 60

    NSString *key = [keys objectAtIndex:0];
    [self.buttonAutoLock setTitle:key forState:UIControlStateNormal];
    [self.buttonAutoLock setTitle:key forState:UIControlStateHighlighted];
    
    //
    
    NSNumber* copyPasswordOnLongPress = [userDefaults valueForKey:@"copyPasswordOnLongPress"];
    BOOL longTouchCopyEnabled = copyPasswordOnLongPress ? [copyPasswordOnLongPress boolValue] : YES;
    
    NSString *title = longTouchCopyEnabled ? @"On" : @"Off";
    [self.buttonLongTouchCopy setTitle:title forState:UIControlStateNormal];
    [self.buttonLongTouchCopy setTitle:title forState:UIControlStateHighlighted];
    
    NSString *aboutString = [NSString stringWithFormat:@"About %@", [Utils getAppName]];
    [self.buttonAbout setTitle:aboutString forState:UIControlStateNormal];
    [self.buttonAbout setTitle:aboutString forState:UIControlStateHighlighted];
}

-(void) viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    self.buttonUnlinkDropbox.hidden = ![[DBSession sharedSession] isLinked];
    self.buttonSignoutGoogleDrive.hidden = ![self.googleDrive isAuthorized];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)onLongTouchCopy:(id)sender {
    UIActionSheet *popup = [[UIActionSheet alloc] initWithTitle:@"Long Touch Copies Password:" delegate:self
                                              cancelButtonTitle:@"Cancel"
                                         destructiveButtonTitle:nil
                                              otherButtonTitles:@"On", @"Off", nil];
    
    popup.tag = 2;
    [popup showInView:[UIApplication sharedApplication].keyWindow];
}

- (IBAction)onAutoClose:(id)sender
{
    UIActionSheet *popup = [[UIActionSheet alloc] initWithTitle:@"Auto Lock Safe Time:" delegate:self
                                              cancelButtonTitle:nil
                                         destructiveButtonTitle:nil
                                              otherButtonTitles:nil];
    
    NSArray *keys = [_autoLockList allKeys];
    NSArray *sortedKeys = [keys sortedArrayUsingComparator:^NSComparisonResult(id a, id b) {
        NSString *first = [_autoLockList objectForKey:a];
        NSString *second = [_autoLockList objectForKey:b];
        return [first compare:second];
    }];
    
    // ObjC Fast Enumeration
    
    for (NSString *title in sortedKeys) {
        [popup addButtonWithTitle:title ];
    }
    
    [popup addButtonWithTitle:@"Cancel"];
    popup.cancelButtonIndex = [_autoLockList count];
    
    popup.tag = 1;
    [popup showInView:[UIApplication sharedApplication].keyWindow];
}

- (void)actionSheet:(UIActionSheet *)popup clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if(popup.tag == 1)
    {
        if(buttonIndex < [_autoLockList count]) // Exclude Cancel
        {
            NSString *key = [popup buttonTitleAtIndex:buttonIndex];
            id seconds = [_autoLockList objectForKey:key];
            
            NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
            [userDefaults setObject:seconds forKey:@"autoLockTimeSeconds"];
            [userDefaults synchronize];

            [self.buttonAutoLock setTitle:key forState:UIControlStateNormal];
            [self.buttonAutoLock setTitle:key forState:UIControlStateHighlighted];
        }
    }
    else if (popup.tag == 2)
    {
        if(buttonIndex != 2) // Cancel
        {
            BOOL longTouchCopyEnabled = (buttonIndex == 0);
            
            NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
            [userDefaults setBool:longTouchCopyEnabled forKey:@"copyPasswordOnLongPress"];
            [userDefaults synchronize];
        
            NSString *title = longTouchCopyEnabled ? @"On" : @"Off";
            [self.buttonLongTouchCopy setTitle:title forState:UIControlStateNormal];
            [self.buttonLongTouchCopy setTitle:title forState:UIControlStateHighlighted];
        }
    }
}

- (IBAction)onUnlinkDropbox:(id)sender
{
    if ([[DBSession sharedSession] isLinked])
    {
        UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"Unlink Dropbox?" message:@"Are you sure you want to unlink StrongBox from Dropbox?" delegate:self cancelButtonTitle:@"No" otherButtonTitles:@"Yes", nil];
        alertView.tag = 1;
        
        [alertView show];
    }
}

- (IBAction)onSignoutGoogleDrive:(id)sender
{
    if([self.googleDrive isAuthorized])
    {
        UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"Sign Out of Google Drive?" message:@"Are you sure you want to sign out of Google Drive?" delegate:self cancelButtonTitle:@"No" otherButtonTitles:@"Yes", nil];
        alertView.tag = 2;
        
        [alertView show];
    }
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if(alertView.tag == 1)
    {
        if (buttonIndex == 1)
        {
            [[DBSession sharedSession] unlinkAll];
        
            self.buttonUnlinkDropbox.hidden = YES;
            
            UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"Unlink Successful" message:@"You have successfully unlinked StrongBox from Dropbox." delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil];
            [alertView show];
        }
    }
    else if(alertView.tag == 2)
    {
        if (buttonIndex == 1)
        {
            [self.googleDrive signout];
            
            self.buttonSignoutGoogleDrive.hidden = YES;
            
            UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"Sign Out Successful" message:@"You have been successfully been signed out of Google Drive." delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil];
            [alertView show];
        }
    }
}


@end
