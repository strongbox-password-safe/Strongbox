//
//  ProgressWindow.m
//  Strongbox
//
//  Created by Mark on 08/12/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
//

#import "ProgressWindow.h"

@interface ProgressWindow ()

@property (weak) IBOutlet NSProgressIndicator *progressBar;
@property (weak) IBOutlet NSTextField *labelOperationDescription;
@property NSString* status;

@end

@implementation ProgressWindow

+ (instancetype)newProgress:(NSString *)status {
    ProgressWindow* ret = [[ProgressWindow alloc] initWithWindowNibName:@"ProgressWindow"];
    ret.status = status;
    return ret;
}

- (void)hide {
    if ( self.window && self.window.sheetParent ) {
        [self.window.sheetParent endSheet:self.window];
    }
}

- (void)windowDidLoad {
    [super windowDidLoad];
    
    self.labelOperationDescription.stringValue = self.status;

    [self.progressBar startAnimation:nil];
}

@end
