//
//  CustomBackgroundTableView.m
//  MacBox
//
//  Created by Strongbox on 21/11/2020.
//  Copyright © 2020 Mark McGuill. All rights reserved.
//

#import "CustomBackgroundTableView.h"

@implementation CustomBackgroundTableView

- (void)drawBackgroundInClipRect:(NSRect)clipRect {
    [super drawBackgroundInClipRect:clipRect];

    NSRect boundsToDraw = clipRect;
    [NSColor.controlBackgroundColor set];
    NSRectFill(boundsToDraw);

    if (self.numberOfRows == 0 && self.emptyString.length) {
        NSMutableParagraphStyle * paragraphStyle = [NSParagraphStyle.defaultParagraphStyle mutableCopy];
        [paragraphStyle setAlignment:NSTextAlignmentCenter];
    
         NSDictionary * attributes = @{
            NSParagraphStyleAttributeName : paragraphStyle,
            NSFontAttributeName : [NSFont systemFontOfSize:NSFont.systemFontSize],
            NSForegroundColorAttributeName : NSColor.labelColor,
        };
        
        CGSize size = [self.emptyString sizeWithAttributes:attributes];
        
        float x_pos = (clipRect.size.width - size.width) / 2;
        float y_pos = (clipRect.size.height - size.height) /2;
        
        CGRect rect = CGRectMake(clipRect.origin.x + x_pos, clipRect.origin.y + y_pos, size.width, size.height);
        [self.emptyString drawInRect:rect withAttributes:attributes];
    }
}

- (void)drawGridInClipRect:(NSRect)clipRect {
    
    
    
}

- (NSMenu*) menuForEvent:(NSEvent*)event {
    if (self.rightClickSelectsItem) {
        
        NSInteger row = [self rowAtPoint:[self convertPoint:event.locationInWindow fromView:nil]];
        if (row >= 0) {
            
            if (! [self isRowSelected:row]) {
                
                [self selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];
            }
        }
    }
    
    return [super menuForEvent:event];
}




- (BOOL)validateProposedFirstResponder:(NSResponder *)responder forEvent:(NSEvent *)event {
    return YES;
}

@end
