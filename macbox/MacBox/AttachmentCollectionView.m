//
//  AttachmentCollectionView.m
//  Strongbox
//
//  Created by Mark on 16/11/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
//

#import "AttachmentCollectionView.h"

@interface AttachmentCollectionView ()

@property NSUInteger clickedItemIndex;

@end

@implementation AttachmentCollectionView

-(void)mouseDown:(NSEvent *)theEvent {
    [super mouseDown:theEvent];
    
    if([theEvent clickCount] > 1) {
        if(self.onDoubleClick) self.onDoubleClick();
    }
}

- (void)keyDown:(NSEvent *)event
{
    unichar firstChar = 0;
    if ([[event charactersIgnoringModifiers] length] > 0) {
        firstChar = [[event charactersIgnoringModifiers] characterAtIndex:0];
    }

    if (firstChar == ' ')
    {
        if(self.onSpaceBar) self.onSpaceBar();
    }
    else {
        [super keyDown:event];
    }
}

@end
