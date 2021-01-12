//
//  OutlineView.m
//  MacBox
//
//  Created by Strongbox on 28/12/2020.
//  Copyright © 2020 Mark McGuill. All rights reserved.
//

#import "OutlineView.h"

@implementation OutlineView

- (void)keyDown:(NSEvent *)theEvent {
//    BOOL cmd = ((theEvent.modifierFlags & NSEventModifierFlagCommand) == NSEventModifierFlagCommand);
    unichar key = [[theEvent charactersIgnoringModifiers] characterAtIndex:0];
//    NSLog(@"%hu - %d", key, theEvent.keyCode);
    
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

@end
