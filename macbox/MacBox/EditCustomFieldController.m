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
#import "PasswordMaker.h"
#import "Settings.h"
#import "ColoredStringHelper.h"
#import "Strongbox-Swift.h"
#import "MacAlerts.h"
#import "SBLog.h"

@interface EditCustomFieldController () <NSTextViewDelegate, NSTextFieldDelegate, NSMenuDelegate>

@property (weak) IBOutlet NSTextField *textFieldKey;
@property (unsafe_unretained) IBOutlet NSTextView *textViewValue;
@property (weak) IBOutlet NSButton *checkboxConcealable;
@property (weak) IBOutlet NSButton *buttonOK;
@property (weak) IBOutlet NSPopUpButton *popupButtonValue;
@property (weak) IBOutlet NSScrollView *borderedScrollNotes;
@property (weak) IBOutlet NSPopUpButton *popupButtonName;

@property BOOL initialLoad;
@end

@implementation EditCustomFieldController

+ (instancetype)fromStoryboard {
    NSStoryboard* sb = [NSStoryboard storyboardWithName:@"EditCustomField" bundle:nil];
    return [sb instantiateInitialController];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.textFieldKey.delegate = self;
    self.textViewValue.delegate = self;
    self.borderedScrollNotes.wantsLayer = YES;
    self.borderedScrollNotes.layer.cornerRadius = 5.0;
    
    self.popupButtonValue.menu.delegate = self;
    self.popupButtonName.menu.delegate = self;

    if ( self.customFieldKeySet.count == 0 ) {
        NSPopUpButtonCell* cell = self.popupButtonName.cell;
        cell.arrowPosition = NSPopUpNoArrow;
    }
    
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
    slog(@"doCommandBySelector-%@", NSStringFromSelector(aSelector));
    
    if (aSelector == @selector(insertTab:)) {
        [self.view.window makeFirstResponder:self.checkboxConcealable];
        return YES;
    }
    else if ( aSelector == @selector(insertBacktab:)) {
        [self.view.window makeFirstResponder:self.textFieldKey];
    }

    return NO;

}

- (void)bindUI {
    if ( self.field ) {
        self.textFieldKey.stringValue = self.field.key;
        
        [self.textViewValue setString:self.field.value];
        self.checkboxConcealable.state = self.field.protected ? NSControlStateValueOn : NSControlStateValueOff;
    }
    
    [self validateOK];
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
    
    const NSSet<NSString*> *keePassReserved;
    
    NSMutableSet* set = Constants.ReservedCustomFieldKeys.mutableCopy;
    [set addObject:kCanonicalEmailFieldName];
    keePassReserved = [set copy];
    
    if ( self.field ) { 
        BOOL same = ([key isEqualToString:self.field.key] && [value isEqualToString:self.field.value] && self.field.protected == protected);
        if ( same ) {
            self.buttonOK.enabled = NO;
            return;
        }
        
        
        
        if ( ![key isEqualToString:self.field.key] ) { 
            BOOL keyIsntAlreadyInUse = ![self.existingKeySet containsObject:key] && ![keePassReserved containsObject:key];
            self.buttonOK.enabled = key.length && keyIsntAlreadyInUse;
        }
        else {
            self.buttonOK.enabled = YES;
        }
    }
    else { 
        BOOL keyIsntAlreadyInUse = ![self.existingKeySet containsObject:key] && ![keePassReserved containsObject:key];
        
        self.buttonOK.enabled = key.length && keyIsntAlreadyInUse;
    }
}

- (IBAction)onOK:(id)sender {
    NSString* value = [NSString stringWithString:self.textViewValue.textStorage.string];

    if ( ![trim(value) isEqualToString:value] ) {
        [MacAlerts twoOptionsWithCancel:NSLocalizedString(@"field_tidy_title_tidy_up_field", @"Tidy Up Field?")
                        informativeText:NSLocalizedString(@"field_tidy_message_tidy_up_field", @"There are some blank characters (e.g. spaces, tabs) at the start or end of this field.\n\nShould Strongbox tidy up these extraneous characters?")
                      option1AndDefault:NSLocalizedString(@"field_tidy_choice_tidy_up_field", @"Tidy Up")
                                option2:NSLocalizedString(@"field_tidy_choice_dont_tidy", @"Don't Tidy")
                                 window:self.view.window
                             completion:^(int response) {
            if ( response == 0 ) {
                [self dismissAndSet:trim(value)];
            }
            else if ( response == 1) {
                [self dismissAndSet:value];
            }
        }];
    }
    else {
        [self dismissAndSet:value];
    }
}

- (void)dismissAndSet:(NSString*)value {
    [self.presentingViewController dismissViewController:self];

    if ( self.onSetField ) {
        NSString* key = trim(self.textFieldKey.stringValue);
        BOOL protected = self.checkboxConcealable.state == NSControlStateValueOn;

        self.onSetField(key, value, protected);
    }
}

- (IBAction)onCancel:(id)sender {
    [self.presentingViewController dismissViewController:self];
}

- (void)menuNeedsUpdate:(NSMenu *)menu {
    if ( menu == self.popupButtonValue.menu ) {
        NSMutableArray<NSString*> *altSuggestions = NSMutableArray.array;
        
        [altSuggestions addObject:[PasswordMaker.sharedInstance generateAlternateForConfig:Settings.sharedInstance.passwordGenerationConfig]];
        [altSuggestions addObject:[PasswordMaker.sharedInstance generateAlternateForConfig:Settings.sharedInstance.passwordGenerationConfig]];
        [altSuggestions addObject:[PasswordMaker.sharedInstance generateForConfig:Settings.sharedInstance.passwordGenerationConfig]];
        [altSuggestions addObject:[PasswordMaker.sharedInstance generateForConfig:Settings.sharedInstance.passwordGenerationConfig]];
        [altSuggestions addObject:[PasswordMaker.sharedInstance generateUsername].lowercaseString];
        [altSuggestions addObject:[PasswordMaker.sharedInstance generateEmail]];
        [altSuggestions addObject:[PasswordMaker.sharedInstance generateRandomWord]];
        [altSuggestions addObject:[PasswordMaker.sharedInstance generateRandomWord]];
         
        [altSuggestions addObject:@( arc4random() ).stringValue];
        [altSuggestions addObject:[NSString stringWithFormat:@"0x%0.8X", arc4random()]];
        
        while ( menu.itemArray.count > 1 ) {
            [menu removeItemAtIndex:menu.itemArray.count - 1];
        }

        NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"menu_item_header_randomly_generated_suggestions", @"Randomly Generated")
                                                      action:nil
                                               keyEquivalent:@""];
        item.enabled = NO;
        [menu addItem:item];

        BOOL colorize = Settings.sharedInstance.colorizePasswords;
        NSString *osxMode = [[NSUserDefaults standardUserDefaults] stringForKey:@"AppleInterfaceStyle"];
        BOOL dark = ([osxMode isEqualToString:@"Dark"]);
        BOOL colorBlind = Settings.sharedInstance.colorizeUseColorBlindPalette;
        
        for ( NSString* suggestion in altSuggestions ) {
            NSAttributedString* colored = [ColoredStringHelper getColorizedAttributedString:suggestion
                                                                                   colorize:colorize
                                                                                   darkMode:dark
                                                                                 colorBlind:colorBlind
                                                                                       font:FontManager.shared.easyReadFont];
            
            NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:@"" action:@selector(onSelectedValueSuggestion:) keyEquivalent:@""];
            item.attributedTitle = colored;
            [menu addItem:item];
        }
    }
    else {
        while ( menu.itemArray.count > 1 ) {
            [menu removeItemAtIndex:menu.itemArray.count - 1];
        }
        
        NSArray<NSString*>* used = [self.customFieldKeySet.allObjects sortedArrayUsingComparator:finderStringComparator];
        
        if ( used.count ) {
            NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"menu_item_header_most_used_suggestions", @"Most Used")
                                                          action:nil
                                                   keyEquivalent:@""];
            item.enabled = NO;
            [menu addItem:item];
            
            for ( NSString* key in used ) {
                NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:key action:@selector(onSelectedNameSuggestion:) keyEquivalent:@""];
                [menu addItem:item];
            }
        }
        else {
            NSPopUpButtonCell* cell = self.popupButtonName.cell;
            cell.arrowPosition = NSPopUpNoArrow;
        }
    }
}

- (void)onSelectedValueSuggestion:(id)sender {
    NSMenuItem* item = sender;
    [self.textViewValue insertText:item.title replacementRange:self.textViewValue.selectedRange];
}

- (void)onSelectedNameSuggestion:(id)sender {
    NSMenuItem* item = sender;
    self.textFieldKey.stringValue = item.title;
}

@end
