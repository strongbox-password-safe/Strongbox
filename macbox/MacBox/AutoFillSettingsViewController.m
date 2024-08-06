//
//  AutoFillSettingsViewController.m
//  Strongbox
//
//  Created by Strongbox on 24/11/2020.
//  Copyright © 2020 Mark McGuill. All rights reserved.
//

#import "AutoFillSettingsViewController.h"
#import "AutoFillManager.h"
#import "Settings.h"
#import "MacAlerts.h"
#import "QuickTypeAutoFillDisplayFormat.h"
#import "Utils.h"
#import "NSArray+Extensions.h"
#import "AutoFillProxyServer.h"
#import "Strongbox-Swift.h"
#import "AdvancedAutoFillSettingsViewController.h"

@interface AutoFillSettingsViewController ()

@property (weak) IBOutlet NSButton *enableAutoFill;
@property (weak) IBOutlet NSPopUpButton *popupAutoUnlock;
@property NSArray<NSNumber*>* autoUnlockOptions;
@property NSTimer* timer;
@property (weak) IBOutlet NSButton *enableSystemExtension;
@property (weak) IBOutlet NSButton *switchCopyTotp;
@property (weak) IBOutlet NSStackView *stackViewProOnlyMessage;
@property (weak) IBOutlet NSTextField *labelConvenienceAutoUnlock;
@property (weak) IBOutlet NSButton *advancedSettings;

@end

@implementation AutoFillSettingsViewController

- (void)viewDidLoad {
    [super viewDidLoad];

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
    
    [self bindUI];
}

- (void)viewDidDisappear {
    [super viewDidDisappear];
    
    [self killRefreshTimer];
}

- (void)viewDidAppear {
    [super viewDidAppear];
    
    [self startRefreshTimer];
}

- (void)bindUI {
    BOOL pro = Settings.sharedInstance.isPro;
    MacDatabasePreferences* meta = self.model.databaseMetadata;

    
    
    
    
    self.stackViewProOnlyMessage.hidden = pro;
 
    
    
    self.enableAutoFill.enabled = pro;
    self.enableAutoFill.state = meta.autoFillEnabled ? NSControlStateValueOn : NSControlStateValueOff;

    
    
    self.switchCopyTotp.enabled = meta.autoFillEnabled && pro;
    self.switchCopyTotp.state = meta.autoFillCopyTotp ? NSControlStateValueOn : NSControlStateValueOff;

    
    
    self.advancedSettings.enabled = meta.autoFillEnabled && pro;
    
    
    
    

    self.enableSystemExtension.enabled = pro && meta.autoFillEnabled;

    BOOL safariEnabled = AutoFillManager.sharedInstance.isOnForStrongbox;
    self.enableSystemExtension.state = safariEnabled ? NSControlStateValueOn : NSControlStateValueOff;

    
    
    self.labelConvenienceAutoUnlock.textColor = (pro && meta.autoFillEnabled && safariEnabled) ? NSColor.labelColor : NSColor.disabledControlTextColor;
    
    self.popupAutoUnlock.enabled = pro && meta.autoFillEnabled && safariEnabled;
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
        self.model.databaseMetadata.autoFillConvenienceAutoUnlockTimeout = val;
        self.model.databaseMetadata.autoFillConvenienceAutoUnlockPassword = nil;
    }
    
    [self bindUI];
}

- (IBAction)onChanged:(id)sender {
    BOOL oldEnabled = self.model.databaseMetadata.autoFillEnabled;

    BOOL autoFillEnabled = self.enableAutoFill.state == NSControlStateValueOn;
    BOOL autoFillCopyTotp = self.switchCopyTotp.state == NSControlStateValueOn;

    self.model.databaseMetadata.autoFillEnabled = autoFillEnabled;
    
    self.model.databaseMetadata.autoFillCopyTotp = autoFillCopyTotp;

    [self bindUI];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        if ( autoFillEnabled != oldEnabled ) { 
            slog(@"AutoFill QuickType was toggles - Clearing Database....");
            [AutoFillManager.sharedInstance clearAutoFillQuickTypeDatabase];
            
            self.model.databaseMetadata.quickTypeEnabled = autoFillEnabled; 
        }
        
        [self.model rebuildMapsAndCaches]; 
    });
}

- (IBAction)onClose:(id)sender {
    [self.view.window cancelOperation:nil];
}

- (void)startRefreshTimer {
    __weak AutoFillSettingsViewController* weakSelf = self;
    
    self.timer = [NSTimer scheduledTimerWithTimeInterval:1. repeats:YES block:^(NSTimer * _Nonnull timer) {
        [weakSelf bindUI];
    }];
}

- (void)killRefreshTimer {
    if ( self.timer != nil ) {
        [self.timer invalidate];
    }
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

- (IBAction)onChromeExtension:(id)sender {
    NSURL* url = [NSURL URLWithString:@"https:

    [[NSWorkspace sharedWorkspace] openURL:url
                             configuration:NSWorkspaceOpenConfiguration.configuration
                         completionHandler:^(NSRunningApplication * _Nullable app, NSError * _Nullable error) {
        if ( error ) {
            slog(@"Launch URL done. Error = [%@]", error);
        }
    }];
}

- (IBAction)onFirefoxExtension:(id)sender {
    NSURL* url = [NSURL URLWithString:@"https:
    
    [[NSWorkspace sharedWorkspace] openURL:url
                             configuration:NSWorkspaceOpenConfiguration.configuration
                         completionHandler:^(NSRunningApplication * _Nullable app, NSError * _Nullable error) {
        if ( error ) {
            slog(@"Launch URL done. Error = [%@]", error);
        }
    }];
}

- (void)prepareForSegue:(NSStoryboardSegue *)segue sender:(id)sender {
    if ([segue.identifier isEqualToString:@"segueToAdvancedSettings"] ) {
        AdvancedAutoFillSettingsViewController* vc = (AdvancedAutoFillSettingsViewController*)segue.destinationController;
        vc.model = self.model;
    }
}

@end
