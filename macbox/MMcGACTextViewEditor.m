//
//  MMcGACTextViewEditor.m
//  Strongbox
//
//  Created by Mark on 09/04/2019.
//  Copyright © 2019 Mark McGuill. All rights reserved.
//

#import "MMcGACTextViewEditor.h"

@implementation MMcGACTextViewEditor

- (NSRange)rangeForUserCompletion { // Required by autocomplete to not just cover words but the entire string
    NSRange range = [super rangeForUserCompletion];
    
    range.location = 0;
    range.length = self.string.length;
    
    return range;
}

@end
