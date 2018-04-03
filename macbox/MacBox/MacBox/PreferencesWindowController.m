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

@interface PreferencesWindowController ()

@end

@implementation PreferencesWindowController

- (IBAction)onOk:(id)sender {
    [self.window.sheetParent endSheet:self.window returnCode:NSModalResponseOK];
}

- (void)windowDidLoad {
    [super windowDidLoad];
    
    [self bindUiToSettings];
    
    NSClickGestureRecognizer *click = [[NSClickGestureRecognizer alloc] initWithTarget:self action:@selector(onChangeParameters:)];
    [self.labelSamplePassword addGestureRecognizer:click];

    NSClickGestureRecognizer *click2 = [[NSClickGestureRecognizer alloc] initWithTarget:self action:@selector(onChangeParameters:)];
    [self.labelClickToRefresh addGestureRecognizer:click2];

    [self refreshSamplePassword];
}

-(void)refreshSamplePassword {
    self.labelSamplePassword.stringValue = [PasswordGenerator generatePassword:Settings.sharedInstance.passwordGenerationParameters];
}
     
- (void)bindUiToSettings {
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

- (IBAction)onChangeParameters:(id)sender {
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
    
    if(params.xkcdWordCount > 50){
        params.xkcdWordCount = 50;
    }
    
    if(!params.useLower && !params.useUpper && !params.useDigits && !params.useSymbols) {
        params.useLower = YES;
        [Alerts info:@"You must use at least one of the character pools." informativeText:@"Invalid Settings" window:self.window completion:nil];
    }
    
    Settings.sharedInstance.passwordGenerationParameters = params;
    
    [self bindUiToSettings];
    
    [self refreshSamplePassword];
}

@end
