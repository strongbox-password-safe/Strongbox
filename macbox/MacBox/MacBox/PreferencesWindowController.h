//
//  PreferencesWindowController.h
//  Strongbox
//
//  Created by Mark on 03/04/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface PreferencesWindowController : NSWindowController

@property (weak) IBOutlet NSButton *radioBasic;
@property (weak) IBOutlet NSButton *radioXkcd;
@property (weak) IBOutlet NSButton *checkboxUseLower;
@property (weak) IBOutlet NSButton *checkboxUseUpper;
@property (weak) IBOutlet NSButton *checkboxUseDigits;
@property (weak) IBOutlet NSButton *checkboxUseSymbols;
@property (weak) IBOutlet NSButton *checkboxUseEasy;
@property (weak) IBOutlet NSTextField *labelMinimumLength;
@property (weak) IBOutlet NSTextField *labelMaximumLength;
@property (weak) IBOutlet NSTextField *labelXkcdWordCount;
@property (weak) IBOutlet NSStepper *stepperMinimumLength;
@property (weak) IBOutlet NSStepper *stepperMaximumLength;
@property (weak) IBOutlet NSStepper *stepperXkcdWordCount;
@property (weak) IBOutlet NSTextField *labelSamplePassword;
@property (weak) IBOutlet NSTextField *labelClickToRefresh;

@property (weak) IBOutlet NSTextField *labelPasswordLength;
@property (weak) IBOutlet NSTextField *labelMinimum;
@property (weak) IBOutlet NSTextField *labelMaximum;
@property (weak) IBOutlet NSTextField *labelWordcount;
@end
