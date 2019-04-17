//
//  ViewController.h
//  MacBox
//
//  Created by Mark on 01/08/2017.
//  Copyright © 2017 Mark McGuill. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "ViewModel.h"
#import "CustomPasswordTextField.h"
#import "AttachmentCollectionView.h"
#import <QuickLook/QuickLook.h>
#import <Quartz/Quartz.h>
#import "ClickableImageView.h"
#import "KSPasswordField.h"

@interface ViewController : NSViewController<   NSOutlineViewDelegate,
                                                NSOutlineViewDataSource,
                                                NSTableViewDelegate,
                                                NSTableViewDataSource>

@property (strong, nonatomic) ViewModel* model;
//-(void)updateDocumentUrl;
@property (weak) IBOutlet ClickableImageView *imageViewGroupDetails;

// App wide fields
@property (weak) IBOutlet NSTableView *tableViewSummary;

@property (weak) IBOutlet NSOutlineView *outlineView;
@property (weak) IBOutlet NSTabView *tabViewLockUnlock;
@property (weak) IBOutlet NSTabView *tabViewRightPane;
@property (weak) IBOutlet NSButton *buttonCreateGroup;
@property (weak) IBOutlet NSButton *buttonCreateRecord;
@property (weak) IBOutlet NSView *emailRow;

// Locked Fields

@property (weak) IBOutlet KSPasswordField *textFieldMasterPassword;

// Record Fields

@property (weak) IBOutlet NSSegmentedControl *searchSegmentedControl;
@property (weak) IBOutlet NSSearchField *searchField;

@property (unsafe_unretained) IBOutlet NSTextView *textViewNotes;
@property (weak) IBOutlet NSButton *buttonUnlockWithTouchId;
@property (weak) IBOutlet ClickableImageView *imageViewShowHidePassword;
@property (weak) IBOutlet NSTextField *textFieldTotp;
@property (weak) IBOutlet NSProgressIndicator *progressTotp;

- (IBAction)onSearch:(id)sender;
- (IBAction)onOutlineViewDoubleClick:(id)sender;
- (IBAction)onEnterMasterPassword:(id)sender;
@property (weak) IBOutlet NSButton *buttonUnlockWithPassword;

// Group View Fields

@property (weak) IBOutlet NSTextField *textFieldSummaryTitle;

- (void)onDetailsWindowClosed:(id)wc;

// Used by Node Details too...

void onSelectedNewIcon(ViewModel* model, Node* item, NSNumber* index, NSData* data, NSUUID* existingCustom, NSWindow* window);

@end

