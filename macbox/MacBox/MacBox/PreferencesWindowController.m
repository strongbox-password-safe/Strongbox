//
//  PreferencesWindowController.m
//  Strongbox
//
//  Created by Mark on 03/04/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
//

#import "PreferencesWindowController.h"

@interface PreferencesWindowController ()

@end

@implementation PreferencesWindowController

+ (BOOL)runModal
{
    PreferencesWindowController* windowController = [[PreferencesWindowController alloc] initWithWindowNibName:@"PreferencesWindowController"];
    
    if ([NSApp runModalForWindow:windowController.window]) {
        return YES;
    }
    
    return NO;
}

- (void)windowDidLoad {
    [super windowDidLoad];
    
    // Implement this method to handle any initialization after your window controller's window has been loaded from its nib file.
}

@end
