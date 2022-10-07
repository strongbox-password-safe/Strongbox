//
//  EnableSystemAutoFillInstructionsViewController.m
//  MacBox
//
//  Created by Strongbox on 25/09/2022.
//  Copyright © 2022 Mark McGuill. All rights reserved.
//

#import "EnableSystemAutoFillInstructionsViewController.h"

@interface EnableSystemAutoFillInstructionsViewController ()<NSPopoverDelegate>

@property BOOL oneTimeIgnoreDismissal;

@end

@implementation EnableSystemAutoFillInstructionsViewController

- (IBAction)onOpenExtensions:(id)sender {
    self.oneTimeIgnoreDismissal = YES;
    
    [NSWorkspace.sharedWorkspace openURL:[NSURL fileURLWithPath:@"/System/Library/PreferencePanes/Extensions.prefPane"]];
}

- (BOOL)popoverShouldClose:(NSPopover *)popover {
    if ( self.oneTimeIgnoreDismissal ) {
        self.oneTimeIgnoreDismissal = NO;
        return NO;
    }
    
    return YES;
}

@end
