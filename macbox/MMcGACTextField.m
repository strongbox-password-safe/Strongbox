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

    
    
    NSMutableData *data = [[NSMutableData alloc] init];
    NSKeyedArchiver *archiver = [[NSKeyedArchiver alloc] initForWritingWithMutableData:data];
    [self.cell encodeWithCoder:archiver];
    [archiver finishEncoding];
    
    NSKeyedUnarchiver *unarchiver = [[NSKeyedUnarchiver alloc] initForReadingWithData:data];
    MMcGACTextFieldCell *cell =  [[MMcGACTextFieldCell alloc] initWithCoder:unarchiver];
    [unarchiver finishDecoding];
    
    
    
    self.cell = cell;
    self.needsDisplay = YES;
    
    self.delegate = self;
}

- (void)controlTextDidBeginEditing:(NSNotification *)obj {
    if(self.onBeginEditing) self.onBeginEditing();
}

- (void)controlTextDidEndEditing:(NSNotification *)obj {
    if(self.onEndEditing) self.onEndEditing();
}

- (void)controlTextDidChange:(NSNotification *)obj {
    if ( self.onTextDidChange ) {
        self.onTextDidChange();
    }
    
    if ( self.completionEnabled && !self.isAutoCompleting && self.stringValue.length ) {
        self.isAutoCompleting = YES;
        NSControl* control = [[obj userInfo] objectForKey:@"NSFieldEditor"];

        [control complete:nil]; 
        
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

- (NSArray<NSString*>*)filterCompletions:(NSString*)prefix {
    if(!self.completions) {
        return @[];
    }
    
    return [[self.completions filter:^BOOL(NSString * _Nonnull obj) {
        return [obj localizedCaseInsensitiveContainsString:prefix];
    }] sortedArrayUsingComparator:finderStringComparator];
}

- (void (^)(void))onImagePasted {
    MMcGACTextFieldCell *cell = (MMcGACTextFieldCell *)self.cell;
    return cell.onImagePasted;
}

- (void)setOnImagePasted:(void (^)(void))onImagePasted {
    MMcGACTextFieldCell *cell = (MMcGACTextFieldCell *)self.cell;
    cell.onImagePasted = onImagePasted;
}

@end
