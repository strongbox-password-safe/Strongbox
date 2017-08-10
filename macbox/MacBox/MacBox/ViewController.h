//
//  ViewController.h
//  MacBox
//
//  Created by Mark on 01/08/2017.
//  Copyright © 2017 Mark McGuill. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "ViewModel.h"

@interface ViewController : NSViewController<NSOutlineViewDelegate, NSOutlineViewDataSource>

@property (strong, nonatomic) ViewModel* model;

@property (weak) IBOutlet NSTextField *textField;
@property (weak) IBOutlet NSOutlineView *outlineView;

@property (weak) IBOutlet NSStackView *stackViewUnlocked;
@property (weak) IBOutlet NSStackView *stackViewLockControls;
@property (weak) IBOutlet NSSecureTextField *textFieldPassword;

- (IBAction)onUnlock:(id)sender;
- (IBAction)onLock:(id)sender;
- (IBAction)onOutlineViewDoubleClick:(id)sender;

@end

