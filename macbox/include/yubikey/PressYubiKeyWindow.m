//
//  PressYubiKeyWindow.m
//  Strongbox
//
//  Created by Mark on 26/02/2020.
//  Copyright © 2020 Mark McGuill. All rights reserved.
//

#import "PressYubiKeyWindow.h"
#import "NSArray+Extensions.h"

@interface PressYubiKeyWindow ()

@end

static PressYubiKeyWindow* instance;

@implementation PressYubiKeyWindow

- (instancetype)init {
    self = [super initWithWindowNibName:@"PressYubiKeyWindow"];
    return self;
}

+ (void)show:(NSWindow*)parentHint {
    dispatch_async(dispatch_get_main_queue(), ^{
        instance = [[PressYubiKeyWindow alloc] init];
        [instance showAsSheet:parentHint];
    });
}

+ (void)hide {
    dispatch_async(dispatch_get_main_queue(), ^{
        [instance hideSheet];
        instance = nil;
    });
}

- (void)showAsSheet:(NSWindow*)parent {
    if (!parent) {
        // Try to auto detect parent if none provide...
        
        parent = NSApplication.sharedApplication.mainWindow ? NSApplication.sharedApplication.mainWindow : NSApplication.sharedApplication.keyWindow;

        if (!parent) {
            //        NSLog(@"windows = [%@] - main = [%@], key = [%@]", NSApplication.sharedApplication.windows, parent, NSApplication.sharedApplication.keyWindow);

            parent = NSApplication.sharedApplication.windows.firstObject;
        }
    }
    
    [parent beginCriticalSheet:instance.window completionHandler:nil];
}

- (void)hideSheet {
    [self.window.sheetParent endSheet:self.window];
}

@end
