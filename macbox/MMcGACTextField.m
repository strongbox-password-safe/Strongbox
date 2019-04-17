//
//  MMcGACTextField.m
//  Strongbox
//
//  Created by Mark on 09/04/2019.
//  Copyright © 2019 Mark McGuill. All rights reserved.
//

#import "MMcGACTextField.h"
#import "MMcGACTextFieldCell.h"
#import "NSArray+Extensions.h"
#import "Utils.h"

@interface MMcGACTextField () <NSTextFieldDelegate>

@property BOOL isAutoCompleting;

@end

@implementation MMcGACTextField

- (void)awakeFromNib {
    [super awakeFromNib];
    
    MMcGACTextFieldCell *cell =  [[MMcGACTextFieldCell alloc] initTextCell:self.stringValue];
    cell.placeholderString = self.placeholderString;

    self.cell = cell;
    self.bordered = YES;
    self.backgroundColor = NSColor.whiteColor;
    self.bezeled = YES;
    self.bezelStyle = NSTextFieldSquareBezel;
    self.enabled = YES;
    self.editable = YES;
    self.selectable = YES;
    
    self.delegate = self;
}

- (NSArray<NSString*>*)filterCompletions:(NSString*)prefix {
    if(!self.completions) {
        return @[];
    }
    
    return [[self.completions filter:^BOOL(NSString * _Nonnull obj) {
        return [obj localizedCaseInsensitiveContainsString:prefix];
    }] sortedArrayUsingComparator:finderStringComparator];
}

- (void)controlTextDidBeginEditing:(NSNotification *)obj {
    if(self.onBeginEditing) self.onBeginEditing();
}

- (void)controlTextDidEndEditing:(NSNotification *)obj {
    if(self.onEndEditing) self.onEndEditing();
}

- (void)controlTextDidChange:(NSNotification *)obj {
    if (self.completionEnabled && !self.isAutoCompleting && self.stringValue.length) {
        self.isAutoCompleting = YES;
        NSControl* control = [[obj userInfo] objectForKey:@"NSFieldEditor"];

        [control complete:nil]; // This is synchronous and the BOOL blocks re-entry
        
        self.isAutoCompleting = NO;
    }
}

- (NSArray<NSString *> *)control:(NSControl *)control
                        textView:(NSTextView *)textView
                     completions:(NSArray<NSString *> *)words
             forPartialWordRange:(NSRange)charRange
             indexOfSelectedItem:(NSInteger *)index {
    NSString* str = textView.textStorage.string;
    if(!str.length) {
        return @[];
    }
    
    NSArray* matches = [self filterCompletions:str];
    *index = -1;
    return matches;
}

@end
