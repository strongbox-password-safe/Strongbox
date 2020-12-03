//
//  FavIconResultTableCellView.m
//  Strongbox
//
//  Created by Mark on 21/12/2019.
//  Copyright © 2019 Mark McGuill. All rights reserved.
//

#import "FavIconResultTableCellView.h"

@interface FavIconResultTableCellView ()

@property (weak) IBOutlet ClickableImageView *imageViewChecked;
@property (weak) IBOutlet NSButton *buttonChooseIcon;

@property BOOL _checked;
@property BOOL _checkable;
@property BOOL _showIconChooseButton;

@property (weak) IBOutlet NSStackView *stackView;

@end

@implementation FavIconResultTableCellView

- (void)awakeFromNib {
    [self setup];
}

- (void)prepareForReuse {
    [self setup];
}

- (void)setup {
    [super prepareForReuse];
    
    self._checked = NO;
    self._checkable = NO;
    self._showIconChooseButton = NO;
    
    self.imageViewChecked.clickable = NO;
    
    __weak FavIconResultTableCellView* weakSelf = self;
    self.imageViewChecked.onClick = ^{
        [weakSelf toggleCheck];
        
        if(self.onCheckChanged) {
            self.onCheckChanged();
        }
    };
    


    [self bindUi];
}

- (void)toggleCheck {
    self.checked = !self._checked;
}

- (BOOL)checked {
    return self._checked;
}

- (void)setChecked:(BOOL)checked {
    self._checked = checked;
   
    dispatch_async(dispatch_get_main_queue(), ^{
        [self bindUi];
    });
}

- (BOOL)checkable {
    return self._checkable;
}

- (void)setCheckable:(BOOL)checkable {
    self._checkable = checkable;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self bindUi];
    });
}

- (BOOL)showIconChooseButton {
    return self._showIconChooseButton;
}

- (void)setShowIconChooseButton:(BOOL)showIconChooseButton {
    self._showIconChooseButton = showIconChooseButton;

    dispatch_async(dispatch_get_main_queue(), ^{
        [self bindUi];
    });
}

- (IBAction)onChooseIcon:(id)sender {
    if(self.onClickChooseIcon) {
        self.onClickChooseIcon();
    }
}

- (void)bindUi {
    self.imageViewChecked.clickable = self._checkable;
    self.imageViewChecked.image = self.checkable ? self.checked ? [NSImage imageNamed:@"checked_checkbox"] : [NSImage imageNamed:@"unchecked_checkbox"] : nil;
    self.imageViewChecked.hidden = !self.checkable;
    self.buttonChooseIcon.hidden = !self._showIconChooseButton;
}

@end
