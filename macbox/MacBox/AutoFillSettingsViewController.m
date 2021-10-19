//
//  AutoFillSettingsViewController.m
//  Strongbox
//
//  Created by Strongbox on 24/11/2020.
//  Copyright © 2020 Mark McGuill. All rights reserved.
//

#import "AutoFillSettingsViewController.h"
#import "DatabasesManager.h"
#import "AutoFillManager.h"
#import "Settings.h"
#import "MacAlerts.h"
#import "QuickTypeAutoFillDisplayFormat.h"
#import "Utils.h"
#import "NSArray+Extensions.h"

@interface AutoFillSettingsViewController ()

@property (weak) IBOutlet NSButton *enableAutoFill;
@property (weak) IBOutlet NSButton *enableQuickType;
@property (weak) IBOutlet NSButton *useWormholeIfUnlocked;
@property (weak) IBOutlet NSTextField *labelProWarning;
@property (weak) IBOutlet NSButton *enableSystemExtension;
@property (weak) IBOutlet NSTextField *labelNavHelp;
@property (weak) IBOutlet NSPopUpButton *popupDisplayFormat;
@property (weak) IBOutlet NSButton *autoLaunchSingle;
@property (weak) IBOutlet NSPopUpButton *popupAutoUnlock;
@property BOOL isOnForStrongbox;

@property (weak) IBOutlet NSButton *includeAlternativeUrls;
@property (weak) IBOutlet NSButton *scanCustomFields;
@property (weak) IBOutlet NSButton *scanNotesForUrls;

@property NSArray<NSNumber*>* autoUnlockOptions;

@end

@implementation AutoFillSettingsViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self.popupDisplayFormat.menu removeAllItems];
    [self.popupDisplayFormat.menu addItemWithTitle:quickTypeFormatString(kQuickTypeFormatTitleThenUsername) action:nil keyEquivalent:@""];
    [self.popupDisplayFormat.menu addItemWithTitle:quickTypeFormatString(kQuickTypeFormatUsernameOnly) action:nil keyEquivalent:@""];
    [self.popupDisplayFormat.menu addItemWithTitle:quickTypeFormatString(kQuickTypeFormatTitleOnly) action:nil keyEquivalent:@""];

    [self.popupAutoUnlock.menu removeAllItems];
    
    NSMutableArray<NSNumber*> *opts = [NSMutableArray arrayWithArray:@[@(-1), @(0), @(15), @(30), @(60), @(120), @(180), @(300), @(600), @(1200), @(1800), @(3600), @(2 * 3600), @(8 * 3600), @(24 * 3600), @(48 * 3600), @(72 * 3600)]];
    
    if ( self.model.databaseMetadata.autoFillConvenienceAutoUnlockTimeout != -1 ) {
        [opts removeObjectAtIndex:0];
    }
    
    self.autoUnlockOptions = opts.copy;
    
    NSArray<NSString*>* optionsStrings = [self.autoUnlockOptions map:^id _Nonnull(NSNumber * _Nonnull obj, NSUInteger idx) {
        return stringForConvenienceAutoUnlock(obj.integerValue);
    }];

    for ( NSString* title in optionsStrings ) {
        [self.popupAutoUnlock.menu addItemWithTitle:title action:nil keyEquivalent:@""];
    }

    self.isOnForStrongbox = AutoFillManager.sharedInstance.isOnForStrongbox; 
    [self bindUI];

    

    __weak id weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        self.isOnForStrongbox = AutoFillManager.sharedInstance.isOnForStrongbox; 
        [weakSelf bindUI];
    });
}

static NSString* stringForConvenienceAutoUnlock(NSInteger val) {
    if (val == -1) {
        return NSLocalizedString(@"generic_preference_not_configured", @"Not Configured");
    }
    else if ( val == 0 ) {
        return NSLocalizedString(@"prefs_vc_setting_disabled", @"Disabled");
    }
    else {
        return [Utils formatTimeInterval:val];
    }
}

- (void)bindUI {
    BOOL pro = Settings.sharedInstance.fullVersion || Settings.sharedInstance.freeTrial;
    self.labelProWarning.hidden = pro;

    
    
    self.autoLaunchSingle.state = Settings.sharedInstance.autoFillAutoLaunchSingleDatabase ? NSControlStateValueOn : NSControlStateValueOff;

    
        
    self.enableSystemExtension.enabled = AutoFillManager.sharedInstance.isPossible && !self.isOnForStrongbox;
    self.enableSystemExtension.state = self.isOnForStrongbox ? NSControlStateValueOn : NSControlStateValueOff;
    self.labelNavHelp.textColor = self.isOnForStrongbox ? NSColor.secondaryLabelColor : nil;
    
    

    
    
    DatabaseMetadata* meta = self.model.databaseMetadata;
    self.enableAutoFill.enabled = AutoFillManager.sharedInstance.isPossible && self.isOnForStrongbox;
    self.enableAutoFill.state = meta.autoFillEnabled ? NSControlStateValueOn : NSControlStateValueOff;

    
    
    self.useWormholeIfUnlocked.state = meta.quickWormholeFillEnabled ? NSControlStateValueOn : NSControlStateValueOff;
    self.useWormholeIfUnlocked.enabled = AutoFillManager.sharedInstance.isPossible && self.isOnForStrongbox && meta.autoFillEnabled;

    

    self.enableQuickType.enabled = AutoFillManager.sharedInstance.isPossible && self.isOnForStrongbox && meta.autoFillEnabled;
    self.enableQuickType.state = meta.quickTypeEnabled ? NSControlStateValueOn : NSControlStateValueOff;
    [self.popupDisplayFormat selectItemAtIndex:meta.quickTypeDisplayFormat];
    self.popupDisplayFormat.enabled = self.enableQuickType.enabled && meta.quickTypeEnabled;

    
    
    self.includeAlternativeUrls.state = meta.autoFillScanAltUrls ? NSControlStateValueOn : NSControlStateValueOff;
    self.scanCustomFields.state = meta.autoFillScanCustomFields ? NSControlStateValueOn : NSControlStateValueOff;
    self.scanNotesForUrls.state = meta.autoFillScanNotes ? NSControlStateValueOn : NSControlStateValueOff;

    self.includeAlternativeUrls.enabled = self.enableQuickType.enabled && meta.quickTypeEnabled;
    self.scanCustomFields.enabled = self.enableQuickType.enabled && meta.quickTypeEnabled;
    self.scanNotesForUrls.enabled = self.enableQuickType.enabled && meta.quickTypeEnabled;

    

    self.popupAutoUnlock.enabled = AutoFillManager.sharedInstance.isPossible && self.isOnForStrongbox && meta.autoFillEnabled;
    NSInteger val = meta.autoFillConvenienceAutoUnlockTimeout;
    NSUInteger index = [self.autoUnlockOptions indexOfObjectPassingTest:^BOOL(NSNumber * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        return obj.integerValue == val;
    }];

    if (index != NSNotFound) {
        [self.popupAutoUnlock selectItemAtIndex:index];
    }
}

- (IBAction)onAutoUnlockChanged:(id)sender {
    NSInteger newIndex = self.popupAutoUnlock.indexOfSelectedItem;
    NSNumber* num = self.autoUnlockOptions[newIndex];
    NSInteger val = num.integerValue;
    
    if ( val != self.model.databaseMetadata.autoFillConvenienceAutoUnlockTimeout ) {
        [DatabasesManager.sharedInstance atomicUpdate:self.model.databaseUuid
                                                touch:^(DatabaseMetadata * _Nonnull metadata) {
            metadata.autoFillConvenienceAutoUnlockTimeout = val;
            metadata.autoFillConvenienceAutoUnlockPassword = nil;
        }];
    }
    
    [self bindUI];
}

- (IBAction)onDisplayFormatChanged:(id)sender {
    NSInteger newIndex = self.popupDisplayFormat.indexOfSelectedItem;
    
    if ( newIndex != self.model.databaseMetadata.quickTypeDisplayFormat ) {
        [DatabasesManager.sharedInstance atomicUpdate:self.model.databaseUuid
                                                touch:^(DatabaseMetadata * _Nonnull metadata) {
            metadata.quickTypeDisplayFormat = newIndex;
        }];

        NSLog(@"AutoFill QuickType Format was changed - Populating Database....");
        
        
        [AutoFillManager.sharedInstance clearAutoFillQuickTypeDatabase];

        DatabaseMetadata* meta = self.model.databaseMetadata;

        [AutoFillManager.sharedInstance updateAutoFillQuickTypeDatabase:self.model.database
                                                           databaseUuid:meta.uuid
                                                          displayFormat:meta.quickTypeDisplayFormat
                                                        alternativeUrls:meta.autoFillScanAltUrls
                                                           customFields:meta.autoFillScanCustomFields
                                                                  notes:meta.autoFillScanNotes];
        
        [self bindUI];
    }
}

- (IBAction)onChanged:(id)sender {
    BOOL oldQuickType = self.model.databaseMetadata.quickTypeEnabled;
    BOOL oldEnabled = self.model.databaseMetadata.autoFillEnabled;

    BOOL autoFillEnabled = self.enableAutoFill.state == NSControlStateValueOn;
    BOOL quickTypeEnabled = self.enableQuickType.state == NSControlStateValueOn;
    BOOL quickWormholeFillEnabled = self.useWormholeIfUnlocked.state == NSControlStateValueOn;

    BOOL autoFillScanAltUrls = self.includeAlternativeUrls.state == NSControlStateValueOn;
    BOOL autoFillScanCustomFields = self.scanCustomFields.state == NSControlStateValueOn;
    BOOL autoFillScanNotes = self.scanNotesForUrls.state == NSControlStateValueOn;

    [DatabasesManager.sharedInstance atomicUpdate:self.model.databaseUuid
                                            touch:^(DatabaseMetadata * _Nonnull metadata) {
        metadata.autoFillEnabled = autoFillEnabled;
        metadata.quickTypeEnabled = quickTypeEnabled;
        metadata.quickWormholeFillEnabled = quickWormholeFillEnabled;
        metadata.autoFillScanAltUrls = autoFillScanAltUrls;
        metadata.autoFillScanCustomFields = autoFillScanCustomFields;
        metadata.autoFillScanNotes = autoFillScanNotes;
    }];
    
    DatabaseMetadata* meta = self.model.databaseMetadata;
    
    

    BOOL quickTypeWasTurnOff = (oldQuickType == YES && oldEnabled == YES) &&
        (meta.quickTypeEnabled == NO || meta.autoFillEnabled == NO);

    if ( quickTypeWasTurnOff ) { 
        NSLog(@"AutoFill QuickType was turned off - Clearing Database....");
        [AutoFillManager.sharedInstance clearAutoFillQuickTypeDatabase];
    }




    BOOL quickTypeOn = (meta.quickTypeEnabled == YES && meta.autoFillEnabled == YES);
    if ( quickTypeOn ) {
        
        [AutoFillManager.sharedInstance clearAutoFillQuickTypeDatabase];

        NSLog(@"AutoFill QuickType was turned off - Populating Database....");
        [AutoFillManager.sharedInstance updateAutoFillQuickTypeDatabase:self.model.database
                                                           databaseUuid:meta.uuid
                                                          displayFormat:meta.quickTypeDisplayFormat
                                                        alternativeUrls:autoFillScanAltUrls
                                                           customFields:autoFillScanCustomFields
                                                                  notes:autoFillScanNotes];
    }

    

    Settings.sharedInstance.autoFillAutoLaunchSingleDatabase = self.autoLaunchSingle.state == NSControlStateValueOn;

    [self bindUI];
}

- (IBAction)onEnableSystemExtension:(id)sender {
    [MacAlerts customOptionWithCancel:NSLocalizedString(@"mac_autofill_enable_extension_title", @"Enable Strongbox Extension")
                 informativeText:NSLocalizedString(@"mac_autofill_enable_extension_message", @"To use AutoFill you must enable the Strongbox Extension in System Preferences. To do this click the 'Open System Preferences...' button below and navigate to:\n\n∙ Extensions > Password AutoFill > Check 'Strongbox'\n\n")
               option1AndDefault:NSLocalizedString(@"mac_autofill_action_open_system_preferences", @"Open System Preferences...")
                          window:self.view.window
                        completion:^(BOOL go) {
        if (go) {
            NSTask *task = [[NSTask alloc] init];
            task.launchPath = @"/bin/sh";
            task.arguments = @[@"-c" , @"open x-apple.systempreferences:com.apple.preference"];
            [task launch];
        }
    }];
}

@end
