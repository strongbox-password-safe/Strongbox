//
//  PressYubiKeyWindow.m
//  Strongbox
//
//  Created by Mark on 26/02/2020.
//  Copyright © 2020 Mark McGuill. All rights reserved.
//

#import "PressHardwareKeyWindow.h"
#import "NSArray+Extensions.h"

static PressHardwareKeyWindow* instance;

@implementation PressHardwareKeyWindow

- (instancetype)init {
    self = [super initWithWindowNibName:@"PressYubiKeyWindow"];
    return self;
}

+ (void)show:(MacHardwareKeyManagerOnDemandUIProviderBlock)parentHint {
    dispatch_async(dispatch_get_main_queue(), ^{
        instance = [[PressHardwareKeyWindow alloc] init];
        NSWindow* window = parentHint();
        [instance showAsSheet:window];
    });
}

+ (void)hide {
    dispatch_async(dispatch_get_main_queue(), ^{
        [instance hideSheet];
        instance = nil;
    });
}

- (void)showAsSheet:(NSWindow*)parent {
    [parent beginCriticalSheet:instance.window completionHandler:nil];
}

- (void)hideSheet {
    [self.window.sheetParent endSheet:self.window];
}

@end
