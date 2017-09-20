//
//  ViewController.h
//  MacBox
//
//  Created by Mark on 01/08/2017.
//  Copyright © 2017 Mark McGuill. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "ViewModel.h"

@interface ViewController : NSViewController<NSOutlineViewDelegate, NSOutlineViewDataSource, NSTextViewDelegate, NSComboBoxDataSource>

@property (strong, nonatomic) ViewModel* model;
-(void)updateDocumentUrl;

// App wide fields

@property (weak) IBOutlet NSOutlineView *outlineView;
@property (weak) IBOutlet NSTabView *tabViewLockUnlock;
@property (weak) IBOutlet NSTabView *tabViewRightPane;
@property (weak) IBOutlet NSTextField *labelLeftStatus;
@property (weak) IBOutlet NSButton *buttonCreateGroup;
@property (weak) IBOutlet NSButton *buttonCreateRecord;

// Locked Fields

@property (weak) IBOutlet NSSecureTextField *textFieldMasterPassword;

// Record Fields

@property (weak) IBOutlet NSSegmentedControl *searchSegmentedControl;
@property (weak) IBOutlet NSSearchField *searchField;
@property (weak) IBOutlet NSButton *buttonRevealDetail;
@property (weak) IBOutlet NSButton *checkboxRevealDetailsImmediately;
@property (weak) IBOutlet NSButton *buttonShowHidePassword;

@property (weak) IBOutlet NSTextField *textFieldTitle;
@property (weak) IBOutlet NSTextField *textFieldUrl;
@property (unsafe_unretained) IBOutlet NSTextView *textViewNotes;
@property (weak) IBOutlet NSTextField *textFieldPw;
@property (weak) IBOutlet NSComboBox *comboboxUsername;

- (IBAction)onSearch:(id)sender;
- (IBAction)onUnlock:(id)sender;
- (IBAction)onOutlineViewDoubleClick:(id)sender;
- (IBAction)onRevealDetails:(id)sender;
- (IBAction)onConcealDetails:(id)sender;
- (IBAction)onEnterMasterPassword:(id)sender;

// Safe Summary Fields

@property (weak) IBOutlet NSTextField *textFieldSafeSummaryPath;
@property (weak) IBOutlet NSTextField *testFieldSafeSummaryUniqueUsernames;
@property (weak) IBOutlet NSTextField *textFieldSafeSummaryUniquePasswords;
@property (weak) IBOutlet NSTextField *textFieldSafeSummaryMostPopularUsername;
@property (weak) IBOutlet NSTextField *textFieldSafeSummaryRecords;
@property (weak) IBOutlet NSTextField *textFieldSafeSummaryGroups;
@property (weak) IBOutlet NSTextField *textFieldSafeSummaryKeyStretchIterations;
@property (weak) IBOutlet NSTextField *textFieldSafeSummaryVersion;
@property (weak) IBOutlet NSTextField *textFieldSafeSummaryLastUpdateUser;
@property (weak) IBOutlet NSTextField *textFieldSafeSummaryLastUpdateHost;
@property (weak) IBOutlet NSTextField *textFieldSafeSummaryLastUpdateApp;
@property (weak) IBOutlet NSTextField *textFieldSafeSummaryLastUpdateTime;

// Group View Fields

@property (weak) IBOutlet NSTextField *textFieldSummaryTitle;

// Concealed View Fields

- (IBAction)onCheckboxRevealDetailsImmediately:(id)sender;

@end

