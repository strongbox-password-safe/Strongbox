//
//  NotesTableViewCell.m
//  test-new-ui
//
//  Created by Mark on 18/04/2019.
//  Copyright © 2019 Mark McGuill. All rights reserved.
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

@end

@implementation NotesTableViewCell

- (void)awakeFromNib {
    [super awakeFromNib];
    self.textView.delegate = self;
    self.horizontalLine.backgroundColor = UIColor.blueColor;
    self.textView.font = self.configuredValueFont;
    self.textView.adjustsFontForContentSizeCategory = YES;
    self.textView.userInteractionEnabled = YES; 

    UITapGestureRecognizer *doubleTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(onTextViewDoubleTap:)];
    [doubleTap setNumberOfTapsRequired:2];
    [doubleTap setNumberOfTouchesRequired:1];
    [self.textView addGestureRecognizer:doubleTap];
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
