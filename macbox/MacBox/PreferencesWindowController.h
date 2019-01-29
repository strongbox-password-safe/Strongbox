//
//  PreferencesWindowController.h
//  Strongbox
//
//  Created by Mark on 03/04/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface PreferencesWindowController : NSWindowController

+ (instancetype)sharedInstance;

- (void)show;
- (void)showOnTab:(NSUInteger)tab;

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
@property (weak) IBOutlet NSTabView *tabView;

@property (weak) IBOutlet NSTextField *labelPasswordLength;
@property (weak) IBOutlet NSTextField *labelMinimum;
@property (weak) IBOutlet NSTextField *labelMaximum;
@property (weak) IBOutlet NSTextField *labelWordcount;

@property (weak) IBOutlet NSButton *checkboxAutoSave;
@property (weak) IBOutlet NSButton *checkboxAlwaysShowPassword;
@property (weak) IBOutlet NSButton *checkboxAlwaysShowUsernameInOutlineView;
@property (weak) IBOutlet NSButton *checkboxAutofillMostPopularUsernameEmail;
@property (weak) IBOutlet NSButton *checkboxAutofillNotes;
@property (weak) IBOutlet NSButton *checkboxAutofillUrl;
@property (weak) IBOutlet NSButton *checkboxKeePassNoSort;

@property (weak) IBOutlet NSButton *radioAutolockNever;
@property (weak) IBOutlet NSButton *radioAutolock1Min;
@property (weak) IBOutlet NSButton *radioAutolock2Min;
@property (weak) IBOutlet NSButton *radioAutolock5Min;

@property (weak) IBOutlet NSSegmentedControl *segmentTitle;
@property (weak) IBOutlet NSTextField *labelCustomTitle;
@property (weak) IBOutlet NSSegmentedControl *segmentUsername;
@property (weak) IBOutlet NSTextField *labelCustomUsername;
@property (weak) IBOutlet NSSegmentedControl *segmentEmail;
@property (weak) IBOutlet NSTextField *labelCustomEmail;
@property (weak) IBOutlet NSSegmentedControl *segmentPassword;
@property (weak) IBOutlet NSTextField *labelCustomPassword;
@property (weak) IBOutlet NSSegmentedControl *segmentUrl;
@property (weak) IBOutlet NSTextField *labelCustomUrl;
@property (weak) IBOutlet NSSegmentedControl *segmentNotes;
@property (weak) IBOutlet NSTextField *labelCustomNotes;

@end
