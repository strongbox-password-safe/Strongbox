//
//  OutlineView.m
//  MacBox
//
//  Created by Strongbox on 28/12/2020.
//  Copyright © 2020 Mark McGuill. All rights reserved.
//

#import "OutlineView.h"
#import "Strongbox-Swift.h"

@implementation OutlineView

- (void)keyDown:(NSEvent *)theEvent {
//    BOOL cmd = ((theEvent.modifierFlags & NSEventModifierFlagCommand) == NSEventModifierFlagCommand);
    unichar key = [[theEvent charactersIgnoringModifiers] characterAtIndex:0];

    
    if (key == NSDeleteCharacter || key == NSBackspaceCharacter || key == 63272) {
        if (self.onDeleteKey) {

            self.onDeleteKey();
        }
    }






    else if ((key == NSEnterCharacter) || (key == NSCarriageReturnCharacter)) {
        if (self.onEnterKey) {
            self.onEnterKey();
  
        }
    }
    else {
        [super keyDown:theEvent];
    }
}

- (NSMenu*)menuForEvent:(NSEvent*)event { 
    
    NSInteger row = [self rowAtPoint:[self convertPoint:event.locationInWindow fromView:nil]];
    if (row >= 0) {
        id item = [self itemAtRow:row];
        
        if ( self.delegate && [self.delegate respondsToSelector:@selector(outlineView:shouldSelectItem:)] ) {
            if ( ![self.delegate outlineView:self shouldSelectItem:item] ) {
                return nil;
            }
        }

        

        if (! [self isRowSelected:row] ) {
            
            [self selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];
        }
    }
    
    return [super menuForEvent:event];
}














































@end
