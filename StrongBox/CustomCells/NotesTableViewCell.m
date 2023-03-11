//
//  NotesTableViewCell.m
//  test-new-ui
//
//  Created by Mark on 18/04/2019.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import "NotesTableViewCell.h"
#import "ItemDetailsViewController.h"
#import "MBAutoGrowingTextView.h"
#import "FontManager.h"

@interface NotesTableViewCell () <UITextViewDelegate>

@property (weak, nonatomic) IBOutlet UIView *horizontalLine;
@property (weak, nonatomic) IBOutlet MBAutoGrowingTextView *textView;
@property BOOL _isEditable;
@property BOOL useEasyReadFont;

@property UITapGestureRecognizer *doubleTap;

@end

@implementation NotesTableViewCell

- (void)awakeFromNib {
    [super awakeFromNib];
    self.textView.delegate = self;    
    self.horizontalLine.backgroundColor = UIColor.labelColor;
    self.textView.font = self.configuredValueFont;
    
    self.textView.adjustsFontForContentSizeCategory = YES;
    
    self.textView.userInteractionEnabled = YES; 
    self.textView.accessibilityLabel = NSLocalizedString(@"notes_cell_textview_accessibility_label", @"Notes Text View");
    
    self.doubleTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(onTextViewDoubleTap:)];
    [self.doubleTap setNumberOfTapsRequired:2];
    [self.doubleTap setNumberOfTouchesRequired:1];
    [self.textView addGestureRecognizer:self.doubleTap];
}

- (void)setEditing:(BOOL)editing animated:(BOOL)animated {
    [super setEditing:editing animated:animated];
    
    if(editing) {
        self.doubleTap.enabled = NO;
    }
    else {
        self.doubleTap.enabled = YES;
    }
}

- (void)onTextViewDoubleTap:(id)sender {
    if(self.onNotesDoubleTap) {
        self.onNotesDoubleTap();
    }
}

- (void)prepareForReuse {
    [super prepareForReuse];
    self.textView.text = @"";
    self.textView.font = self.configuredValueFont;
    self._isEditable = NO;
}

- (void)setNotes:(NSString *)notes editable:(BOOL)editable useEasyReadFont:(BOOL)useEasyReadFont {
    self.textView.text = notes;
    self._isEditable = editable;
    self.useEasyReadFont = useEasyReadFont;
    self.textView.font = self.configuredValueFont;

    [self bindUiToSettings];
}

- (void)textViewDidChange:(UITextView *)textView {
    if(self.onNotesEdited) {
        self.onNotesEdited([NSString stringWithString:textView.textStorage.string]);
    }
    
    [self.textView layoutSubviews];
    [[NSNotificationCenter defaultCenter] postNotificationName:CellHeightsChangedNotification object:self];
}

- (void)bindUiToSettings {
    self.horizontalLine.hidden = !self._isEditable;
    self.textView.editable = self._isEditable;
    
    [self.textView layoutSubviews];
    [[NSNotificationCenter defaultCenter] postNotificationName:CellHeightsChangedNotification object:self];
}

- (UIFont*)configuredValueFont {
    return self.useEasyReadFont ? FontManager.sharedInstance.easyReadFont : FontManager.sharedInstance.regularFont;
}

@end
