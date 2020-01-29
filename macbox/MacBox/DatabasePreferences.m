//
//  DatabasePreferences.m
//  Strongbox
//
//  Created by Mark on 27/01/2020.
//  Copyright © 2020 Mark McGuill. All rights reserved.
//

#import "DatabasePreferences.h"
#import "BookmarksHelper.h"
#import "Utils.h"
#import "SecretStore.h"

@interface DatabasePreferences ()

@property (weak) IBOutlet NSTextField *textFieldPath;
@property (weak) IBOutlet NSTextField *textFieldDatabaseName;
@property (weak) IBOutlet NSTextField *textFieldKeyFile;
@property (weak) IBOutlet NSButton *checkboxUseTouchId;
@property (weak) IBOutlet NSButton *checkboxRequirePasswordAfter;
@property (weak) IBOutlet NSSlider *sliderExpiry;
@property (weak) IBOutlet NSTextField *labelExpiryPeriod;
@property (weak) IBOutlet NSTextField *passwordStorageSummary;

@end

@implementation DatabasePreferences

- (void)viewDidAppear {
    [super viewDidAppear];
    
    [self bindUi];
}

- (void)bindUi {
    // TODO: Disable if Biometrics unavailable... ?
    
    self.textFieldDatabaseName.stringValue = self.metadata.nickName;
    self.textFieldPath.stringValue = [BookmarksHelper getExpressUrlFromBookmark:self.metadata.storageInfo].path;
    self.textFieldKeyFile.stringValue = self.metadata.keyFileBookmark ? [BookmarksHelper getExpressUrlFromBookmark:self.metadata.keyFileBookmark].absoluteString : @"None";
    
    // TODO: Localize
    
    self.checkboxUseTouchId.state = self.metadata.isTouchIdEnabled ? NSOnState : NSOffState;
    
    self.checkboxRequirePasswordAfter.state = self.metadata.touchIdPasswordExpiryPeriodHours == -1 ? NSOffState : NSOnState;
    self.checkboxRequirePasswordAfter.enabled  = self.metadata.isTouchIdEnabled;
    
    self.sliderExpiry.enabled = self.metadata.isTouchIdEnabled && self.metadata.touchIdPasswordExpiryPeriodHours != -1; 
    
    self.labelExpiryPeriod.stringValue = [self getExpiryPeriodString:self.metadata.touchIdPasswordExpiryPeriodHours];

    self.passwordStorageSummary.stringValue = SecretStore.sharedInstance.secureEnclaveAvailable ? @"Secure Enclave" : @"Secure Enclave Unavailable"; // Localize - TODO
}

- (NSString*)getExpiryPeriodString:(NSInteger)expiryPeriod {
    if(expiryPeriod == -1) {
        return @"Never Expires"; // Localize - TODO
    }
    else if (expiryPeriod == 0) {
        return @"Expires on App Exit";
    }
    else {
        return [Utils formatTimeInterval:expiryPeriod];
    }
}

- (IBAction)onSlider:(id)sender {
    NSLog(@"%@", self.sliderExpiry.stringValue);
}

@end
