//
//  ClickableImageView.m
//  Strongbox
//
//  Created by Mark on 25/02/2019.
//  Copyright © 2019 Mark McGuill. All rights reserved.
//

#import "ClickableImageView.h"

@interface ClickableImageView ()

@property BOOL isShowClickableBorder;
@property BOOL isClickable;

@end

@implementation ClickableImageView

- (void)awakeFromNib {
    self.wantsLayer = YES;
    self.layer.cornerRadius = 5;
    self.layer.masksToBounds = YES;
}

- (BOOL)clickable {
    return _isClickable;
}

- (void)setClickable:(BOOL)clickable {
    _isClickable = clickable;
    
    [self showHideClickableBorder];
}

- (BOOL)showClickableBorder {
    return _isShowClickableBorder;
}

- (void)setShowClickableBorder:(BOOL)showClickableBorder {
    _isShowClickableBorder = showClickableBorder;

    [self showHideClickableBorder];
}

- (void)showHideClickableBorder {
    if(_isShowClickableBorder && _isClickable) {
        self.layer.borderWidth = 1.5f;
        self.layer.borderColor = [NSColor colorWithRed:0 green:0.5f blue:0.7f alpha:0.65f].CGColor;
    }
    else {
        self.layer.borderColor = nil;
        self.layer.borderWidth = 0.0f;
    }
}

//- (BOOL)acceptsFirstResponder {
//    return YES;
//}

- (void)mouseDown:(NSEvent *)theEvent
{
    // NB: Required for mouse up to work that we override here...
}

- (void)mouseUp:(NSEvent *)theEvent
{
    //NSLog(@"mouseUp");
    if(self.clickable && self.onClick) {
        self.onClick();
    }
}

@end
