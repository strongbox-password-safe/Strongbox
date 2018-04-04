//
//  NSAdvancedTextField.m
//  Strongbox
//
//  Created by Mark on 19/09/2017.
//  Copyright © 2017 Mark McGuill. All rights reserved.
//

#import "NSAdvancedTextField.h"

@implementation NSAdvancedTextField

- (void)mouseUp:(NSEvent *)theEvent
{
    NSInteger clickCount = [theEvent clickCount];
    if (clickCount > 1) {
        if(self.multipleClickHandler) {
            self.multipleClickHandler(clickCount);
        }
    }
}

@end
