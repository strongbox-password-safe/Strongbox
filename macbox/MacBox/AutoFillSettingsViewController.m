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

@interface AutoFillSettingsViewController ()

@property (weak) IBOutlet NSButton *enableAutoFill;
@property (weak) IBOutlet NSButton *enableQuickType;
@property (weak) IBOutlet NSButton *useWormholeIfUnlocked;
@property (weak) IBOutlet NSPopUpButton *popupDisplayFormat;
@property (weak) IBOutlet NSPopUpButton *popupAutoUnlock;
@property (weak) IBOutlet NSButton *includeAlternativeUrls;
@property (weak) IBOutlet NSButton *scanCustomFields;
@property (weak) IBOutlet NSButton *scanNotesForUrls;
@property (weak) IBOutlet NSButton *addUnconcealedFields;
@property (weak) IBOutlet NSButton *addConcealedFields;

@property (weak) IBOutlet NSTextField *labelProWarning;
@property (weak) IBOutlet NSView *viewInstructions;

@property NSArray<NSNumber*>* autoUnlockOptions;
@property NSTimer* timer;

@property (weak) IBOutlet NSStackView *topStackView;
@property (weak) IBOutlet NSStackView *quickTypeStack;
@property (weak) IBOutlet NSStackView *basicStack;

@property (weak) IBOutlet NSView *viewQuickTypeDisplayFormat;
@property (weak) IBOutlet NSView *wormholeOptionView;
@property (weak) IBOutlet NSView *quickTypeHeaderView;
@property (weak) IBOutlet NSView *convenienceUnlockOptionView;

@end

@implementation AutoFillSettingsViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self.popupDisplayFormat.menu removeAllItems];
    [self.popupDisplayFormat.menu addItemWithTitle:quickTypeFormatString(kQuickTypeFormatTitleThenUsername) action:nil keyEquivalent:@""];
    [self.popupDisplayFormat.menu addItemWithTitle:quickTypeFormatString(kQuickTypeFormatUsernameOnly) action:nil keyEquivalent:@""];
    [self.popupDisplayFormat.menu addItemWithTitle:quickTypeFormatString(kQuickTypeFormatTitleOnly) action:nil keyEquivalent:@""];

    [self.popupDisplayFormat.menu addItemWithTitle:quickTypeFormatString(kQuickTypeFormatDatabaseThenTitleThenUsername) action:nil keyEquivalent:@""];
    [self.popupDisplayFormat.menu addItemWithTitle:quickTypeFormatString(kQuickTypeFormatDatabaseThenTitle) action:nil keyEquivalent:@""];
    [self.popupDisplayFormat.menu addItemWithTitle:quickTypeFormatString(kQuickTypeFormatDatabaseThenUsername) action:nil keyEquivalent:@""];

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

    
    
    [self.topStackView setCustomSpacing:20 afterView:self.basicStack];
    [self.basicStack setCustomSpacing:20 afterView:self.wormholeOptionView];
    [self.quickTypeStack setCustomSpacing:20 afterView:self.addUnconcealedFields];
    
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

- (void)startRefreshTimer {
    if ( @available(macOS 10.12, *) ){
        __weak AutoFillSettingsViewController* weakSelf = self;
        
        self.timer = [NSTimer scheduledTimerWithTimeInterval:1. repeats:YES block:^(NSTimer * _Nonnull timer) {
            [weakSelf bindUI];
        }];
    }
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

- (void)bindUI {
    BOOL pro = Settings.sharedInstance.isProOrFreeTrial;
    BOOL isOnForStrongbox = AutoFillManager.sharedInstance.isOnForStrongbox;
    BOOL featureIsAvailable;

    if( @available(macOS 11.0, *) ) {
        featureIsAvailable = YES;
    }
    else {
        featureIsAvailable = NO;
    }
    
    if ( !pro ) {
        self.labelProWarning.hidden = NO;
    }
    else if ( !featureIsAvailable ) {
        self.labelProWarning.hidden = NO;
        self.labelProWarning.stringValue = NSLocalizedString(@"autofill_app_preferences_only_avail_big_sur", @"AutoFill is only available on macOS Big Sur+");
        self.labelProWarning.textColor = NSColor.systemOrangeColor;
        self.labelProWarning.alignment = NSCenterTextAlignment;
    }
    else if ( isOnForStrongbox ) {
        self.labelProWarning.hidden = NO;
        self.labelProWarning.stringValue = NSLocalizedString(@"strongbox_is_enabled_for_autofill", @"✅ Strongbox is enabled for Password AutoFill");
        self.labelProWarning.textColor = NSColor.secondaryLabelColor;
        self.labelProWarning.alignment = NSLeftTextAlignment;
    }
    else {
        self.labelProWarning.hidden = YES;
    }

    self.viewInstructions.hidden = isOnForStrongbox || !pro || !featureIsAvailable;
    self.basicStack.hidden = !isOnForStrongbox || !featureIsAvailable || !pro;
    self.quickTypeStack.hidden =  !isOnForStrongbox || !featureIsAvailable || !pro;
    
    
    
    MacDatabasePreferences* meta = self.model.databaseMetadata;
    self.enableAutoFill.enabled = AutoFillManager.sharedInstance.isPossible && isOnForStrongbox;
    self.enableAutoFill.state = meta.autoFillEnabled ? NSControlStateValueOn : NSControlStateValueOff;

    

    BOOL autoFillOn = meta.autoFillEnabled && AutoFillManager.sharedInstance.isPossible && isOnForStrongbox && featureIsAvailable && pro;

    self.useWormholeIfUnlocked.state = meta.quickWormholeFillEnabled ? NSControlStateValueOn : NSControlStateValueOff;
    self.useWormholeIfUnlocked.enabled = autoFillOn;
    self.wormholeOptionView.hidden = !autoFillOn;

    
    
    self.quickTypeHeaderView.hidden = !autoFillOn;
    self.convenienceUnlockOptionView.hidden = !autoFillOn;
    
    

    self.quickTypeStack.hidden = !autoFillOn;
    
    self.enableQuickType.enabled = AutoFillManager.sharedInstance.isPossible && isOnForStrongbox && meta.autoFillEnabled;
    self.enableQuickType.state = meta.quickTypeEnabled ? NSControlStateValueOn : NSControlStateValueOff;
    
    self.enableQuickType.hidden = !autoFillOn;
    
    

    BOOL quickTypeOn = autoFillOn && meta.quickTypeEnabled;

    [self.popupDisplayFormat selectItemAtIndex:meta.quickTypeDisplayFormat];

    self.popupDisplayFormat.enabled = quickTypeOn;

    self.includeAlternativeUrls.state = meta.autoFillScanAltUrls ? NSControlStateValueOn : NSControlStateValueOff;
    self.scanCustomFields.state = meta.autoFillScanCustomFields ? NSControlStateValueOn : NSControlStateValueOff;
    self.scanNotesForUrls.state = meta.autoFillScanNotes ? NSControlStateValueOn : NSControlStateValueOff;
    self.addConcealedFields.state = meta.autoFillConcealedFieldsAsCreds ? NSControlStateValueOn : NSControlStateValueOff;
    self.addUnconcealedFields.state = meta.autoFillUnConcealedFieldsAsCreds ? NSControlStateValueOn : NSControlStateValueOff;

    self.includeAlternativeUrls.hidden = !quickTypeOn;
    self.scanCustomFields.hidden = !quickTypeOn;
    self.scanNotesForUrls.hidden = !quickTypeOn;
    self.addConcealedFields.hidden = !quickTypeOn;
    self.addUnconcealedFields.hidden = !quickTypeOn;
    self.viewQuickTypeDisplayFormat.hidden = !quickTypeOn;
    
    

    self.popupAutoUnlock.enabled = AutoFillManager.sharedInstance.isPossible && isOnForStrongbox && meta.autoFillEnabled;
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

- (IBAction)onDisplayFormatChanged:(id)sender {
    NSInteger newIndex = self.popupDisplayFormat.indexOfSelectedItem;
    
    if ( newIndex != self.model.databaseMetadata.quickTypeDisplayFormat ) {
        self.model.databaseMetadata.quickTypeDisplayFormat = newIndex;
    
        NSLog(@"AutoFill QuickType Format was changed - Populating Database....");
        
        
        [AutoFillManager.sharedInstance clearAutoFillQuickTypeDatabase];

        MacDatabasePreferences* meta = self.model.databaseMetadata;

        [AutoFillManager.sharedInstance updateAutoFillQuickTypeDatabase:self.model.commonModel.database
                                                           databaseUuid:meta.uuid
                                                          displayFormat:meta.quickTypeDisplayFormat
                                                        alternativeUrls:meta.autoFillScanAltUrls
                                                           customFields:meta.autoFillScanCustomFields
                                                                  notes:meta.autoFillScanNotes
                                           concealedCustomFieldsAsCreds:meta.autoFillConcealedFieldsAsCreds
                                         unConcealedCustomFieldsAsCreds:meta.autoFillUnConcealedFieldsAsCreds
                                                               nickName:meta.nickName];
        
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

    BOOL concealedCustomFieldsAsCreds = self.addConcealedFields.state == NSControlStateValueOn;
    BOOL unConcealedCustomFieldsAsCreds = self.addUnconcealedFields.state == NSControlStateValueOn;
    
    self.model.databaseMetadata.autoFillEnabled = autoFillEnabled;
    self.model.databaseMetadata.quickTypeEnabled = quickTypeEnabled;
    self.model.databaseMetadata.quickWormholeFillEnabled = quickWormholeFillEnabled;
    self.model.databaseMetadata.autoFillScanAltUrls = autoFillScanAltUrls;
    self.model.databaseMetadata.autoFillScanCustomFields = autoFillScanCustomFields;
    self.model.databaseMetadata.autoFillScanNotes = autoFillScanNotes;
    self.model.databaseMetadata.autoFillConcealedFieldsAsCreds = concealedCustomFieldsAsCreds;
    self.model.databaseMetadata.autoFillUnConcealedFieldsAsCreds = unConcealedCustomFieldsAsCreds;

    MacDatabasePreferences* meta = self.model.databaseMetadata;
    
    

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
        [AutoFillManager.sharedInstance updateAutoFillQuickTypeDatabase:self.model.commonModel.database
                                                           databaseUuid:meta.uuid
                                                          displayFormat:meta.quickTypeDisplayFormat
                                                        alternativeUrls:autoFillScanAltUrls
                                                           customFields:autoFillScanCustomFields
                                                                  notes:autoFillScanNotes
                                           concealedCustomFieldsAsCreds:concealedCustomFieldsAsCreds
                                         unConcealedCustomFieldsAsCreds:unConcealedCustomFieldsAsCreds
                                                               nickName:meta.nickName];
    }

    [self bindUI];
}

- (IBAction)onClose:(id)sender {
    [self.view.window cancelOperation:nil];
}

- (IBAction)onOpenExtensions:(id)sender {
    [NSWorkspace.sharedWorkspace openURL:[NSURL fileURLWithPath:@"/System/Library/PreferencePanes/Extensions.prefPane"]];
}

@end
