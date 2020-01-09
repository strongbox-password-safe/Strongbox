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

- (void)onFileChangedByOtherApplication;
- (void)resetModel:(ViewModel *)model;

- (IBAction)onSearch:(id)sender;
- (IBAction)onOutlineViewDoubleClick:(id)sender;
- (IBAction)onEnterMasterPassword:(id)sender;
@property (weak) IBOutlet NSButton *buttonUnlockWithPassword;

// Group View Fields

@property (weak) IBOutlet NSTextField *textFieldSummaryTitle;

// Used by Node Details too...

void onSelectedNewIcon(ViewModel* model, Node* item, NSNumber* index, NSData* data, NSUUID* existingCustom, NSWindow* window);

- (void)autoPromptForTouchIdIfDesired;

@end

