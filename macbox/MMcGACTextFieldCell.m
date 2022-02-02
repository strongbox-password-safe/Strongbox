//
//  MMcGACTextFieldCell.m
//  Strongbox
//
//  Created by Mark on 09/04/2019.
//  Copyright © 2019 Mark McGuill. All rights reserved.
//

#import "MMcGACTextFieldCell.h"
#import "MMcGACTextViewEditor.h"

@interface MMcGACTextFieldCell ()

@property MMcGACTextViewEditor* theFieldEditor;

@end

@implementation MMcGACTextFieldCell

- (NSTextView *)fieldEditorForView:(NSView *)controlView {
    if (self.theFieldEditor == nil) {
        self.theFieldEditor = [[MMcGACTextViewEditor alloc] init];
        self.theFieldEditor.onImagePasted = self.onImagePasted;
        [self.theFieldEditor setFieldEditor:YES];
    }

    return self.theFieldEditor;
}

@end
