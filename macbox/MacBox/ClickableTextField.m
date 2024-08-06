//
//  ClickableTextField.m
//  MacBox
//
//  Created by Strongbox on 20/11/2020.
//  Copyright © 2020 Mark McGuill. All rights reserved.
//

#import "ClickableTextField.h"

@implementation ClickableTextField

- (void)mouseDown:(NSEvent *)event {
//    slog(@"mouseDown");
    // Must be overridden for mouseUp below to function
}

- (void)resetCursorRects {
    [self discardCursorRects];
    
    if ( self.isEnabled ) {
        [self addCursorRect:self.bounds cursor:NSCursor.pointingHandCursor];
    }
}

- (void)mouseUp:(NSEvent *)event {    
    if ( self.onClick && self.isEnabled ) {
        self.onClick();
    }
}

@end
