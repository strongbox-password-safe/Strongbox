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
        self.layer.borderWidth = 2.0f;
        self.layer.borderColor = NSColor.linkColor.CGColor; 
    }
    else {
        self.layer.borderColor = nil;
        self.layer.borderWidth = 0.0f;
    }
}





- (void)resetCursorRects {
    [self discardCursorRects];
    
    [self addCursorRect:self.bounds cursor:NSCursor.pointingHandCursor];
}

- (void)mouseDown:(NSEvent *)theEvent {
    
}

- (void)mouseUp:(NSEvent *)theEvent
{
    
    if(self.clickable && self.onClick) {
        self.onClick();
    }
}

@end
