//
//  PreferencesWindowController.m
//  Strongbox
//
//  Created by Mark on 03/04/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
//

#import "PreferencesWindowController.h"
#import "Settings.h"
#import "PasswordGenerator.h"
#import "Alerts.h"
#import "AppDelegate.h"

@interface PreferencesWindowController ()

@property (weak) IBOutlet NSButton *switchAutoClearClipboard;
@property (weak) IBOutlet NSSlider *sliderAutoClearClipboardTimeout;
@property (weak) IBOutlet NSTextField *labelClearClipboardTimeout;
@property (weak) IBOutlet NSButton *checkboxShowTotpCodes;
@property (weak) IBOutlet NSButton *checkboxShowRecycleBinInBrowse;
@property (weak) IBOutlet NSButton *checkboxShowRecycleBinInSearch;
@property (weak) IBOutlet NSButton *checkboxFloatDetailsWindowsOnTop;
@property (weak) IBOutlet NSButton *checkboxAlternatingGrid;
@property (weak) IBOutlet NSButton *checkboxHorizontalGridLines;
@property (weak) IBOutlet NSButton *checkboxVerticalGridLines;
@property (weak) IBOutlet NSButton *checkboxShowAutoCompleteSuggestions;
@property (weak) IBOutlet NSButton *checkboxShowPopupNotifications;
@property (weak) IBOutlet NSButton *checkboxTitleIsEditable;
@property (weak) IBOutlet NSButton *checkboxOtherFieldsAreEditable;
@property (weak) IBOutlet NSButton *checkboxDereferenceQuickView;
@property (weak) IBOutlet NSButton *checkboxDereferenceOutlineView;
@property (weak) IBOutlet NSButton *checkboxDereferenceSearch;


@end

@implementation PreferencesWindowController

+ (instancetype)sharedInstance {
    static PreferencesWindowController *sharedInstance = nil;
    static dispatch_once_t onceToken;
    
    dispatch_once(&onceToken, ^{
        sharedInstance = [[PreferencesWindowController alloc] initWithWindowNibName:@"PreferencesWindowController"];
    });
    
    return sharedInstance;
}

- (void)cancel:(id)sender { // Pick up escape key
    [self close];
}

- (void)show {
    [self showWindow:nil];
}

- (void)showOnTab:(NSUInteger)tab {
    [self show];
    [self.tabView selectTabViewItemAtIndex:tab];
}

- (void)windowDidLoad {
    [super windowDidLoad];

    [self bindPasswordUiToSettings];
    [self bindGeneralUiToSettings];
    [self bindAutoFillToSettings];
    [self bindAutoLockToSettings];
    [self bindAutoClearClipboard];
    
    NSClickGestureRecognizer *click = [[NSClickGestureRecognizer alloc] initWithTarget:self action:@selector(onChangePasswordParameters:)];
    [self.labelSamplePassword addGestureRecognizer:click];
    
    [self refreshSamplePassword];
}

- (void)bindGeneralUiToSettings {
    self.checkboxAutoSave.state = Settings.sharedInstance.autoSave ? NSOnState : NSOffState;
    self.checkboxAlwaysShowPassword.state = Settings.sharedInstance.alwaysShowPassword ? NSOnState : NSOffState;
    self.checkboxKeePassNoSort.state = Settings.sharedInstance.uiDoNotSortKeePassNodesInBrowseView ? NSOnState : NSOffState;
    self.checkboxShowTotpCodes.state = Settings.sharedInstance.doNotShowTotp ? NSOffState : NSOnState;
    self.checkboxShowRecycleBinInBrowse.state = Settings.sharedInstance.doNotShowRecycleBinInBrowse ? NSOffState : NSOnState;
    self.checkboxShowRecycleBinInSearch.state = Settings.sharedInstance.showRecycleBinInSearchResults ? NSOnState : NSOffState;
    self.checkboxFloatDetailsWindowsOnTop.state = Settings.sharedInstance.doNotFloatDetailsWindowOnTop ? NSOffState : NSOnState;
    self.checkboxAlternatingGrid.state = Settings.sharedInstance.noAlternatingRows ? NSOffState : NSOnState;
    self.checkboxHorizontalGridLines.state = Settings.sharedInstance.showHorizontalGrid ? NSOnState : NSOffState;
    self.checkboxVerticalGridLines.state = Settings.sharedInstance.showVerticalGrid ? NSOnState : NSOffState;
    self.checkboxShowAutoCompleteSuggestions.state = Settings.sharedInstance.doNotShowAutoCompleteSuggestions ? NSOffState : NSOnState;
    self.checkboxShowPopupNotifications.state = Settings.sharedInstance.doNotShowChangeNotifications ? NSOffState : NSOnState;
    self.checkboxTitleIsEditable.state = Settings.sharedInstance.outlineViewTitleIsReadonly ? NSOffState : NSOnState;
    self.checkboxOtherFieldsAreEditable.state = Settings.sharedInstance.outlineViewEditableFieldsAreReadonly ? NSOffState : NSOnState;
    self.checkboxDereferenceQuickView.state = Settings.sharedInstance.dereferenceInQuickView ? NSOnState : NSOffState;
    self.checkboxDereferenceOutlineView.state = Settings.sharedInstance.dereferenceInOutlineView ? NSOnState : NSOffState;
    self.checkboxDereferenceSearch.state = Settings.sharedInstance.dereferenceDuringSearch ? NSOnState : NSOffState;
}

- (IBAction)onGeneralSettingsChange:(id)sender {
    Settings.sharedInstance.alwaysShowPassword = self.checkboxAlwaysShowPassword.state == NSOnState;
    Settings.sharedInstance.autoSave = self.checkboxAutoSave.state == NSOnState;
    Settings.sharedInstance.uiDoNotSortKeePassNodesInBrowseView = self.checkboxKeePassNoSort.state == NSOnState;
    Settings.sharedInstance.doNotShowTotp = self.checkboxShowTotpCodes.state == NSOffState;
    Settings.sharedInstance.doNotShowRecycleBinInBrowse = self.checkboxShowRecycleBinInBrowse.state == NSOffState;
    Settings.sharedInstance.showRecycleBinInSearchResults = self.checkboxShowRecycleBinInSearch.state == NSOnState;
    Settings.sharedInstance.doNotFloatDetailsWindowOnTop = self.checkboxFloatDetailsWindowsOnTop.state == NSOffState;
    Settings.sharedInstance.noAlternatingRows = self.checkboxAlternatingGrid.state == NSOffState;
    Settings.sharedInstance.showHorizontalGrid = self.checkboxHorizontalGridLines.state == NSOnState;
    Settings.sharedInstance.showVerticalGrid = self.checkboxVerticalGridLines.state == NSOnState;
    Settings.sharedInstance.doNotShowAutoCompleteSuggestions = self.checkboxShowAutoCompleteSuggestions.state == NSOffState;
    Settings.sharedInstance.doNotShowChangeNotifications = self.checkboxShowPopupNotifications.state == NSOffState;
    Settings.sharedInstance.outlineViewTitleIsReadonly = self.checkboxTitleIsEditable.state == NSOffState;
    Settings.sharedInstance.outlineViewEditableFieldsAreReadonly = self.checkboxOtherFieldsAreEditable.state == NSOffState;
    Settings.sharedInstance.dereferenceInQuickView = self.checkboxDereferenceQuickView.state == NSOnState;
    Settings.sharedInstance.dereferenceInOutlineView = self.checkboxDereferenceOutlineView.state == NSOnState;
    Settings.sharedInstance.dereferenceDuringSearch = self.checkboxDereferenceSearch.state == NSOnState;

    [self bindGeneralUiToSettings];
    [[NSNotificationCenter defaultCenter] postNotificationName:kPreferencesChangedNotification object:nil];
}

-(void) bindAutoFillToSettings {
    AutoFillNewRecordSettings* settings = Settings.sharedInstance.autoFillNewRecordSettings;

    int index = [self autoFillModeToSegmentIndex:settings.titleAutoFillMode];
    self.segmentTitle.selectedSegment = index;
    self.labelCustomTitle.stringValue = settings.titleAutoFillMode == kCustom ? settings.titleCustomAutoFill : @"";
    
    // Username Options: None / Most Used / Custom
    
    // KLUDGE: This is a bit hacky but saves some RSI typing... :/
    index = [self autoFillModeToSegmentIndex:settings.usernameAutoFillMode];
    self.segmentUsername.selectedSegment = index;
    self.labelCustomUsername.stringValue = settings.usernameAutoFillMode == kCustom ? settings.usernameCustomAutoFill : @"";
    
    // Password Options: None / Most Used / Generated / Custom
    
    index = [self autoFillModeToSegmentIndex:settings.passwordAutoFillMode];
    self.segmentPassword.selectedSegment = index;
    self.labelCustomPassword.stringValue = settings.passwordAutoFillMode == kCustom ? settings.passwordCustomAutoFill : @"";
    
    // Email Options: None / Most Used / Custom
    
    index = [self autoFillModeToSegmentIndex:settings.emailAutoFillMode];
    self.segmentEmail.selectedSegment = index;
    self.labelCustomEmail.stringValue = settings.emailAutoFillMode == kCustom ? settings.emailCustomAutoFill : @"";
    
    // URL Options: None / Custom
    
    index = [self autoFillModeToSegmentIndex:settings.urlAutoFillMode];
    self.segmentUrl.selectedSegment = index;
    self.labelCustomUrl.stringValue = settings.urlAutoFillMode == kCustom ? settings.urlCustomAutoFill : @"";
    
    // Notes Options: None / Custom
    
    index = [self autoFillModeToSegmentIndex:settings.notesAutoFillMode];
    self.segmentNotes.selectedSegment = index;
    self.labelCustomNotes.stringValue = settings.notesAutoFillMode == kCustom ? settings.notesCustomAutoFill : @"";
}

-(void) bindAutoLockToSettings {
    NSInteger alt = Settings.sharedInstance.autoLockTimeoutSeconds;
    
    self.radioAutolockNever.state = alt == 0 ? NSOnState : NSOffState;
    self.radioAutolock1Min.state = alt == 60 ? NSOnState : NSOffState;
    self.radioAutolock2Min.state = alt == 120 ? NSOnState : NSOffState;
    self.radioAutolock5Min.state = alt == 300 ? NSOnState : NSOffState;
    self.radioAutolock10Min.state = alt == 600 ? NSOnState : NSOffState;
    self.radioAutolock30Min.state = alt == 1800 ? NSOnState : NSOffState;
    self.radioAutolock60Min.state = alt == 3600 ? NSOnState : NSOffState;
}

- (void)bindPasswordUiToSettings {
    PasswordGenerationParameters *params = Settings.sharedInstance.passwordGenerationParameters;
    
    self.radioBasic.state = params.algorithm == kBasic ? NSOnState : NSOffState;
    self.radioXkcd.state = params.algorithm == kXkcd ? NSOnState : NSOffState;
    self.checkboxUseLower.state = params.useLower ? NSOnState : NSOffState;
    self.checkboxUseUpper.state = params.useUpper ? NSOnState : NSOffState;
    self.checkboxUseDigits.state = params.useDigits ? NSOnState : NSOffState;
    self.checkboxUseSymbols.state = params.useSymbols ? NSOnState : NSOffState;
    self.checkboxUseEasy.state = params.easyReadOnly ? NSOnState : NSOffState;
    
    self.labelMinimumLength.stringValue =  [NSString stringWithFormat:@"%d", params.minimumLength];
    self.labelMaximumLength.stringValue =  [NSString stringWithFormat:@"%d", params.maximumLength];
    self.labelXkcdWordCount.stringValue =  [NSString stringWithFormat:@"%d", params.xkcdWordCount];
    
    self.stepperMinimumLength.integerValue = params.minimumLength;
    self.stepperMaximumLength.integerValue = params.maximumLength;
    self.stepperXkcdWordCount.integerValue = params.xkcdWordCount;
    
    self.checkboxUseLower.enabled = params.algorithm == kBasic;
    self.checkboxUseUpper.enabled = params.algorithm == kBasic;
    self.checkboxUseDigits.enabled = params.algorithm == kBasic;
    self.checkboxUseSymbols.enabled = params.algorithm == kBasic;
    self.checkboxUseEasy.enabled = params.algorithm == kBasic;
    
    self.labelMinimumLength.enabled = params.algorithm == kBasic;
    self.labelMaximumLength.enabled = params.algorithm == kBasic;
    self.labelXkcdWordCount.enabled = params.algorithm == kXkcd;

    self.labelPasswordLength.textColor = params.algorithm == kBasic ? [NSColor controlTextColor] : [NSColor disabledControlTextColor];
    self.labelMinimum.textColor = params.algorithm == kBasic ? [NSColor controlTextColor] : [NSColor disabledControlTextColor];
    self.labelMaximum.textColor = params.algorithm == kBasic ? [NSColor controlTextColor] : [NSColor disabledControlTextColor];
    self.labelWordcount.textColor = params.algorithm == kXkcd ? [NSColor controlTextColor] : [NSColor disabledControlTextColor];
    
    self.stepperMinimumLength.enabled = params.algorithm == kBasic;
    self.stepperMaximumLength.enabled = params.algorithm == kBasic;
    self.stepperXkcdWordCount.enabled = params.algorithm == kXkcd;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (IBAction)onChangePasswordParameters:(id)sender { 
    PasswordGenerationParameters *params = Settings.sharedInstance.passwordGenerationParameters;
    
    params.algorithm = self.radioBasic.state == NSOnState ? kBasic : kXkcd;
    //self.radioXkcd.state == NSOnState;
    params.useLower = self.checkboxUseLower.state == NSOnState;
    params.useUpper = self.checkboxUseUpper.state == NSOnState;
    params.useDigits = self.checkboxUseDigits.state == NSOnState;
    params.useSymbols = self.checkboxUseSymbols.state == NSOnState;
    params.easyReadOnly = self.checkboxUseEasy.state == NSOnState;
    
    params.minimumLength = (int)self.stepperMinimumLength.integerValue;
    params.maximumLength = (int)self.stepperMaximumLength.integerValue;
    params.xkcdWordCount = (int)self.stepperXkcdWordCount.integerValue;
    
    if(params.minimumLength > params.maximumLength) {
        params.minimumLength = params.maximumLength;
    }
    
    if(params.minimumLength <= 0) {
        params.minimumLength = 1;
    }
    
    if(params.maximumLength > 512){
        params.maximumLength = 512;
    }
    
    if(params.maximumLength < params.minimumLength) {
        params.maximumLength = params.minimumLength;
    }

    if(params.xkcdWordCount < 2){
        params.xkcdWordCount = 2;
    }
    
    if(params.xkcdWordCount > 50){
        params.xkcdWordCount = 50;
    }
    
    if(!params.useLower && !params.useUpper && !params.useDigits && !params.useSymbols) {
        params.useLower = YES;
        [Alerts info:@"You must use at least one of the character pools." informativeText:@"Invalid Settings" window:self.window completion:nil];
    }
    
    Settings.sharedInstance.passwordGenerationParameters = params;
    
    [self bindPasswordUiToSettings];
    [self refreshSamplePassword];
}

- (IBAction)onAutolockChange:(id)sender {
    if(self.radioAutolockNever.state == NSOnState) {
        Settings.sharedInstance.autoLockTimeoutSeconds = 0;
    }
    else if (self.radioAutolock1Min.state == NSOnState) {
        Settings.sharedInstance.autoLockTimeoutSeconds = 60;
    }
    else if (self.radioAutolock2Min.state == NSOnState) {
        Settings.sharedInstance.autoLockTimeoutSeconds = 120;
    }
    else if (self.radioAutolock5Min.state == NSOnState) {
        Settings.sharedInstance.autoLockTimeoutSeconds = 300;
    }
    else if (self.radioAutolock10Min.state == NSOnState) {
        Settings.sharedInstance.autoLockTimeoutSeconds = 600;
    }
    else if (self.radioAutolock30Min.state == NSOnState) {
        Settings.sharedInstance.autoLockTimeoutSeconds = 1800;
    }
    else if (self.radioAutolock60Min.state == NSOnState) {
        Settings.sharedInstance.autoLockTimeoutSeconds = 3600;
    }
    
    [self bindAutoLockToSettings];
    [[NSNotificationCenter defaultCenter] postNotificationName:kPreferencesChangedNotification object:nil];
}

- (IBAction)onTitleSegment:(id)sender {
    AutoFillNewRecordSettings* settings = Settings.sharedInstance.autoFillNewRecordSettings;

    long selected = self.segmentTitle.selectedSegment;
    settings.titleAutoFillMode = selected == 0 ? kDefault : selected == 1 ? kSmartUrlFill : kCustom;
    
    if(settings.titleAutoFillMode == kCustom) {
        NSString* response = [[Alerts alloc] input:@"Please enter your custom Title auto fill" defaultValue:settings.titleCustomAutoFill allowEmpty:NO];

        if(response) {
            settings.titleCustomAutoFill = response;
        }
    }
    
    Settings.sharedInstance.autoFillNewRecordSettings = settings;
    [self bindAutoFillToSettings];
}

- (IBAction)onUsernameSegment:(id)sender {
    AutoFillNewRecordSettings* settings = Settings.sharedInstance.autoFillNewRecordSettings;
    
    long selected = self.segmentUsername.selectedSegment;
    settings.usernameAutoFillMode = selected == 0 ? kNone : selected == 1 ? kMostUsed : kCustom;
    
    if(settings.usernameAutoFillMode == kCustom) {
        NSString* response = [[Alerts alloc] input:@"Please enter your custom Username auto fill" defaultValue:settings.usernameCustomAutoFill allowEmpty:NO];
        
        if(response) {
            settings.usernameCustomAutoFill = response;
        }
    }
    
    Settings.sharedInstance.autoFillNewRecordSettings = settings;
    [self bindAutoFillToSettings];
}

- (IBAction)onEmailSegment:(id)sender {
    AutoFillNewRecordSettings* settings = Settings.sharedInstance.autoFillNewRecordSettings;
    
    long selected = self.segmentEmail.selectedSegment;
    settings.emailAutoFillMode = selected == 0 ? kNone : selected == 1 ? kMostUsed : kCustom;
    
    if(settings.emailAutoFillMode == kCustom) {
        NSString* response = [[Alerts alloc] input:@"Please enter your custom Email auto fill" defaultValue:settings.emailCustomAutoFill allowEmpty:NO];
        
        if(response) {
            settings.emailCustomAutoFill = response;
        }
    }
    
    Settings.sharedInstance.autoFillNewRecordSettings = settings;
    [self bindAutoFillToSettings];
}

- (IBAction)onPasswordSegment:(id)sender {
    AutoFillNewRecordSettings* settings = Settings.sharedInstance.autoFillNewRecordSettings;
    
    long selected = self.segmentPassword.selectedSegment;
    settings.passwordAutoFillMode = selected == 0 ? kNone : selected == 1 ? kGenerated : kCustom;
    
    if(settings.passwordAutoFillMode == kCustom) {
        NSString* response = [[Alerts alloc] input:@"Please enter your custom Password auto fill" defaultValue:settings.passwordCustomAutoFill allowEmpty:NO];
        
        if(response) {
            settings.passwordCustomAutoFill = response;
        }
    }
    
    Settings.sharedInstance.autoFillNewRecordSettings = settings;
    [self bindAutoFillToSettings];
}

- (IBAction)onUrlSegment:(id)sender {
    AutoFillNewRecordSettings* settings = Settings.sharedInstance.autoFillNewRecordSettings;
    
    long selected = self.segmentUrl.selectedSegment;
    settings.urlAutoFillMode = selected == 0 ? kNone : selected == 1 ? kSmartUrlFill : kCustom;
    
    if(settings.urlAutoFillMode == kCustom) {
        NSString* response = [[Alerts alloc] input:@"Please enter your custom URL auto fill" defaultValue:settings.urlCustomAutoFill allowEmpty:NO];
        
        if(response) {
            settings.urlCustomAutoFill = response;
        }
    }
    
    Settings.sharedInstance.autoFillNewRecordSettings = settings;
    [self bindAutoFillToSettings];
}

- (IBAction)onNotesSegment:(id)sender {
    AutoFillNewRecordSettings* settings = Settings.sharedInstance.autoFillNewRecordSettings;
    
    long selected = self.segmentNotes.selectedSegment;
    settings.notesAutoFillMode = selected == 0 ? kNone : selected == 1 ? kClipboard : kCustom;
    
    if(settings.notesAutoFillMode == kCustom) {
        NSString* response = [[Alerts alloc] input:@"Please enter your custom Notes auto fill" defaultValue:settings.notesCustomAutoFill allowEmpty:NO];
        
        if(response) {
            settings.notesCustomAutoFill = response;
        }
    }
    
    Settings.sharedInstance.autoFillNewRecordSettings = settings;
    [self bindAutoFillToSettings];
}

-(void)refreshSamplePassword {
    self.labelSamplePassword.stringValue = [PasswordGenerator generatePassword:Settings.sharedInstance.passwordGenerationParameters];
}

- (int)autoFillModeToSegmentIndex:(AutoFillMode)mode {
    // KLUDGE: This is a bit hacky but saves some RSI typing... :/
    
    switch (mode) {
        case kNone:
        case kDefault:
            return 0;
            break;
        case kMostUsed:
        case kSmartUrlFill:
        case kClipboard:
        case kGenerated:
            return 1;
            break;
        case kCustom:
            return 2;
            break;
        default:
            NSLog(@"Ruh ROh... ");
            break;
    }
}

- (void)bindAutoClearClipboard {
    self.switchAutoClearClipboard.state = Settings.sharedInstance.clearClipboardEnabled ? NSOnState : NSOffState;
    self.sliderAutoClearClipboardTimeout.integerValue = Settings.sharedInstance.clearClipboardAfterSeconds;
    self.labelClearClipboardTimeout.stringValue = [NSString stringWithFormat:@"%ld Seconds", Settings.sharedInstance.clearClipboardAfterSeconds];

    self.sliderAutoClearClipboardTimeout.enabled = Settings.sharedInstance.clearClipboardEnabled;
}

- (IBAction)onAutoClearClipboard:(id)sender {
    NSLog(@"onAutoClearClipboard: [%d]", self.switchAutoClearClipboard.state == NSOnState);
    
    Settings.sharedInstance.clearClipboardEnabled = self.switchAutoClearClipboard.state == NSOnState;
    
    [self bindAutoClearClipboard];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:kPreferencesChangedNotification object:nil];
}

- (IBAction)onAutoClearClipboardSlider:(id)sender {
    NSLog(@"onAutoClearClipboardSlider: [%d]", self.sliderAutoClearClipboardTimeout.intValue);
    
    Settings.sharedInstance.clearClipboardAfterSeconds = self.sliderAutoClearClipboardTimeout.integerValue;
    
    [self bindAutoClearClipboard];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:kPreferencesChangedNotification object:nil];
}

@end
