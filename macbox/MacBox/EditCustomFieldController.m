//
//  EditCustomFieldController.m
//  MacBox
//
//  Created by Strongbox on 24/03/2021.
//  Copyright © 2021 Mark McGuill. All rights reserved.
//

#import "EditCustomFieldController.h"
#import "Utils.h"
#import "Entry.h"

@interface EditCustomFieldController () <NSTextViewDelegate, NSTextFieldDelegate>

@property (weak) IBOutlet NSTextField *textFieldKey;

@property (unsafe_unretained) IBOutlet NSTextView *textViewValue;
@property (weak) IBOutlet NSButton *buttonGenerate;
@property (weak) IBOutlet NSButton *checkboxConcealable;
@property (weak) IBOutlet NSButton *buttonOK;

@property BOOL initialLoad;
@end

@implementation EditCustomFieldController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.textFieldKey.delegate = self;
    self.textViewValue.delegate = self;
    [self bindUI];
}

- (void)viewDidAppear {
    [super viewDidAppear];
    
    if ( !self.initialLoad ) {
        self.initialLoad = YES;
        


        NSRange range = self.textFieldKey.currentEditor.selectedRange;
        [self.textFieldKey.currentEditor setSelectedRange:NSMakeRange(range.length, 0)];
    }
}
- (BOOL)textView:(NSTextView *)aTextView doCommandBySelector:(SEL)aSelector {
    NSLog(@"doCommandBySelector-%@", NSStringFromSelector(aSelector));
    
    if (aSelector == @selector(insertTab:)) {
        [self.view.window makeFirstResponder:self.checkboxConcealable];

        
        return YES;
    }

    return NO;

}

- (void)bindUI {
    if ( self.field ) {
        self.textFieldKey.stringValue = self.field.key;
        self.textFieldKey.enabled = NO;
        
        [self.textViewValue setString:self.field.value];
        self.checkboxConcealable.state = self.field.protected ? NSControlStateValueOn : NSControlStateValueOff;
    }
    
    self.buttonGenerate.hidden = YES;
    
    [self validateOK];
}

- (IBAction)onGenerate:(id)sender {

}

- (void)textDidChange:(NSNotification *)notification {

    [self validateOK];
}

- (void)controlTextDidChange:(NSNotification *)obj {

    [self validateOK];
}

- (IBAction)onToggleConcealable:(id)sender {
    [self validateOK];
}

- (void)validateOK {
    NSString* key = trim(self.textFieldKey.stringValue);
    NSString* value = [NSString stringWithString:self.textViewValue.textStorage.string];
    BOOL protected = self.checkboxConcealable.state == NSControlStateValueOn;

    if ( self.field ) { 
        BOOL same = ([key isEqualToString:self.field.key] && [value isEqualToString:self.field.value] && self.field.protected == protected);
        
        self.buttonOK.enabled = !same;
    }
    else { 
        const NSSet<NSString*> *keePassReserved = [Entry reservedCustomFieldKeys];
        BOOL keyIsntAlreadyInUse = ![self.existingKeySet containsObject:key] && ![keePassReserved containsObject:key];
        
        self.buttonOK.enabled = key.length && keyIsntAlreadyInUse;
    }
}

- (IBAction)onOK:(id)sender {
    [self.presentingViewController dismissViewController:self];

    if ( self.onSetField ) {
        NSString* key = trim(self.textFieldKey.stringValue);
        NSString* value = [NSString stringWithString:self.textViewValue.textStorage.string];
        BOOL protected = self.checkboxConcealable.state == NSControlStateValueOn;

        self.onSetField(key, value, protected);
    }
}

- (IBAction)onCancel:(id)sender {
    [self.presentingViewController dismissViewController:self];
}

@end
