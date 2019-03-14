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
                                                NSTextViewDelegate,
                                                NSTextFieldDelegate,
                                                NSComboBoxDataSource,
                                                NSTableViewDataSource,
                                                NSTableViewDelegate,
                                                NSCollectionViewDataSource,
                                                NSCollectionViewDelegate,
                                                QLPreviewPanelDataSource,
                                                QLPreviewPanelDelegate>

@property (strong, nonatomic) ViewModel* model;
//-(void)updateDocumentUrl;
@property (weak) IBOutlet ClickableImageView *imageViewGroupDetails;

// App wide fields
@property (weak) IBOutlet NSTableView *tableViewSummary;
@property (weak) IBOutlet NSTableView *tableViewCustomFields;

@property (weak) IBOutlet AttachmentCollectionView *attachmentsView;
@property (weak) IBOutlet NSOutlineView *outlineView;
@property (weak) IBOutlet NSTabView *tabViewLockUnlock;
@property (weak) IBOutlet NSTabView *tabViewRightPane;
@property (weak) IBOutlet NSButton *buttonCreateGroup;
@property (weak) IBOutlet NSButton *buttonCreateRecord;
@property (weak) IBOutlet NSView *emailRow;
@property (weak) IBOutlet NSView *attachmentsRow;
@property (weak) IBOutlet NSView *customFieldsRow;

// Locked Fields

@property (weak) IBOutlet KSPasswordField *textFieldMasterPassword;

// Record Fields

@property (weak) IBOutlet NSSegmentedControl *searchSegmentedControl;
@property (weak) IBOutlet NSSearchField *searchField;
@property (weak) IBOutlet NSButton *buttonRevealDetail;
@property (weak) IBOutlet NSButton *checkboxRevealDetailsImmediately;
@property (weak) IBOutlet NSButton *buttonShowHidePassword;
@property (weak) IBOutlet NSButton *buttonGeneratePassword;

@property (weak) IBOutlet NSTextField *textFieldTitle;
@property (weak) IBOutlet NSTextField *textFieldUrl;
@property (unsafe_unretained) IBOutlet NSTextView *textViewNotes;
@property (weak) IBOutlet NSTextField *textFieldPw;
@property (weak) IBOutlet CustomPasswordTextField *textFieldHiddenPassword;
@property (weak) IBOutlet NSComboBox *comboboxUsername;
@property (weak) IBOutlet NSComboBox *comboBoxEmail;
@property (weak) IBOutlet NSButton *buttonUnlockWithTouchId;
@property (weak) IBOutlet ClickableImageView *imageViewIcon;
@property (weak) IBOutlet ClickableImageView *imageViewShowHidePassword;
@property (weak) IBOutlet NSTextField *textFieldTotp;
@property (weak) IBOutlet NSView *viewPasswordRow;
@property (weak) IBOutlet NSLayoutConstraint *viewPasswordRowHeightConstraint;
@property (weak) IBOutlet NSProgressIndicator *progressTotp;

- (IBAction)onSearch:(id)sender;
- (IBAction)onOutlineViewDoubleClick:(id)sender;
- (IBAction)onRevealDetails:(id)sender;
- (IBAction)onConcealDetails:(id)sender;
- (IBAction)onEnterMasterPassword:(id)sender;
@property (weak) IBOutlet NSButton *buttonUnlockWithPassword;

// Group View Fields

@property (weak) IBOutlet NSTextField *textFieldSummaryTitle;

// Concealed View Fields

- (IBAction)onCheckboxRevealDetailsImmediately:(id)sender;

@end

