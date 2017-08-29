//
//  ViewController.h
//  MacBox
//
//  Created by Mark on 01/08/2017.
//  Copyright © 2017 Mark McGuill. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "ViewModel.h"

@interface ViewController : NSViewController<NSOutlineViewDelegate, NSOutlineViewDataSource, NSTextViewDelegate>

@property (strong, nonatomic) ViewModel* model;
-(void)updateDocumentUrl;

@property (weak) IBOutlet NSOutlineView *outlineView;
@property (weak) IBOutlet NSStackView *stackViewLockControls;
@property (weak) IBOutlet NSStackView *stackViewSummaryView;

@property (weak) IBOutlet NSSecureTextField *textFieldMasterPassword;

@property (weak) IBOutlet NSTextField *textFieldTitle;
@property (weak) IBOutlet NSTextField *textFieldUsername;
@property (weak) IBOutlet NSTextField *textFieldUrl;
@property (unsafe_unretained) IBOutlet NSTextView *textViewNotes;
@property (weak) IBOutlet NSTextField *textFieldPw;
@property (weak) IBOutlet NSButton *buttonRevealDetails;
@property (weak) IBOutlet NSStackView *stackViewRevealButton;

@property (weak) IBOutlet NSSegmentedControl *searchSegmentedControl;
@property (weak) IBOutlet NSSearchField *searchField;

- (IBAction)onSearch:(id)sender;
- (IBAction)onUnlock:(id)sender;

- (IBAction)onOutlineViewDoubleClick:(id)sender;
- (IBAction)onRevealDetails:(id)sender;
- (IBAction)onConcealDetails:(id)sender;
- (IBAction)onEnterMasterPassword:(id)sender;

@property (weak) IBOutlet NSTextField *textFieldSummaryTitle;
@property (weak) IBOutlet NSImageView *imageViewSummary;

@property (weak) IBOutlet NSButton *checkboxRevealDetailsImmediately;
- (IBAction)onCheckboxRevealDetailsImmediately:(id)sender;
@property (weak) IBOutlet NSButton *buttonShowHidePassword;
@property (weak) IBOutlet NSTextField *labelLeftStatus;

@property (weak) IBOutlet NSTabView *tabViewLockUnlock;
@property (weak) IBOutlet NSTabView *tabViewRightPane;

@end

