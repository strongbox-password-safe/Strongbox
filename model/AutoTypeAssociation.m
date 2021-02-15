//
//  AutoTypeAssociation.m
//  Strongbox
//
//  Created by Strongbox on 15/11/2020.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import "AutoTypeAssociation.h"

@implementation AutoTypeAssociation

- (BOOL)isEqual:(id)object {
    if (object == nil) {
        return NO;
    }
    
    if (self == object) {
        return YES;
    }
    
    if (![object isKindOfClass:[AutoTypeAssociation class]]) {
        return NO;
    }
    
    AutoTypeAssociation* other = (AutoTypeAssociation*)object;

    if ((self.window == nil && other.window != nil) || (self.window != nil && ![self.window isEqual:other.window] )) {
        return NO;
    }

    if ((self.keystrokeSequence == nil && other.keystrokeSequence != nil) || (self.keystrokeSequence != nil && ![self.keystrokeSequence isEqual:other.keystrokeSequence] )) {
        return NO;
    }

    return YES;
}

@end
