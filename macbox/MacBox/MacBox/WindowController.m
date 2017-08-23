//
//  WindowController.m
//  MacBox
//
//  Created by Mark on 07/08/2017.
//  Copyright © 2017 Mark McGuill. All rights reserved.
//

#import "WindowController.h"
#import "Document.h"

@interface WindowController ()

@end

@implementation WindowController

- (void)windowDidLoad {
    self.shouldCascadeWindows = YES;
    
    [super windowDidLoad];
}

- (void)setDirty:(BOOL)dirty {
    [self synchronizeWindowTitleWithDocumentName];
}

- (NSString*)windowTitleForDocumentDisplayName:(NSString *)displayName {
    Document* doc = self.document;
    return [NSString stringWithFormat:@"%@%@", displayName, doc.dirty ? @" [*edited]" : @""];
}

@end
