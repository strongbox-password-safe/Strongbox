//
//  TableViewWithRightClickSelect.m
//  MacBox
//
//  Created by Strongbox on 31/03/2021.
//  Copyright © 2021 Mark McGuill. All rights reserved.
//

#import "TableViewWithRightClickSelect.h"

@implementation TableViewWithRightClickSelect

- (NSMenu*)menuForEvent:(NSEvent*)event { // Allows right click selection
    // Get to row at point
    NSInteger row = [self rowAtPoint:[self convertPoint:event.locationInWindow fromView:nil]];
    if (row >= 0) {
        
        if (! [self isRowSelected:row]) {
            
            [self selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];
        }
    }
    
    return [super menuForEvent:event];
}

@end
