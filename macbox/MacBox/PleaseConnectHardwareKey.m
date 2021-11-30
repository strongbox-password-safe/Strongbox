//
//  PleaseConnectHardwareKey.m
//  MacBox
//
//  Created by Strongbox on 05/11/2021.
//  Copyright © 2021 Mark McGuill. All rights reserved.
//

#import "PleaseConnectHardwareKey.h"
#import "NSArray+Extensions.h"

static PleaseConnectHardwareKey* instance;

@interface PleaseConnectHardwareKey () <NSWindowDelegate>

@property (nonatomic, copy, nullable) void (^completion)(BOOL userCancelled);
@property (weak) IBOutlet NSButton *buttonTryAgain;

@end

@implementation PleaseConnectHardwareKey

- (instancetype)init {
    self = [super initWithWindowNibName:@"ConnectHardwareKey"];
    return self;
}

+ (void)show:(NSWindow *)parentHint completion:(void (^)(BOOL))completion {
    dispatch_async(dispatch_get_main_queue(), ^{
        instance = [[PleaseConnectHardwareKey alloc] init];
        [instance showAsSheet:parentHint completion:completion];
    });
}

+ (void)hide {
    dispatch_async(dispatch_get_main_queue(), ^{
        [instance hideSheet:YES];
        instance = nil;
    });
}

- (void)showAsSheet:(NSWindow*)parent completion:(void (^)(BOOL))completion {
    self.window.delegate = self;

    if (!parent) {
        
        
        parent = NSApplication.sharedApplication.mainWindow ? NSApplication.sharedApplication.mainWindow : NSApplication.sharedApplication.keyWindow;

        if (!parent) {
            

            parent = NSApplication.sharedApplication.windows.firstObject;
        }
    }
    self.completion = completion;
    
    [parent beginCriticalSheet:instance.window completionHandler:nil];
}

- (void)hideSheet:(BOOL)cancelled {
    [self.window.sheetParent endSheet:self.window];
    
    if ( self.completion ) {
        self.completion(cancelled);
        self.completion = nil;
    }
}

- (IBAction)onCancel:(id)sender {
    [self hideSheet:YES];
}

- (IBAction)onTryAgain:(id)sender {
    [self hideSheet:NO];
}

@end
