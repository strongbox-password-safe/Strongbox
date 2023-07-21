//
//  BrowseOutlineView.m
//  MacBox
//
//  Created by Strongbox on 19/07/2023.
//  Copyright © 2023 Mark McGuill. All rights reserved.
//

#import "BrowseOutlineView.h"
#import "Strongbox-Swift.h"

@implementation BrowseOutlineView

- (BOOL)validateProposedFirstResponder:(NSResponder *)responder forEvent:(NSEvent *)event {
    if ( [responder isKindOfClass:HyperlinkTextField.class] ) { 
        return YES;
    }
    
    return [super validateProposedFirstResponder:responder forEvent:event];
}

@end
