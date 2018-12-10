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

@end

@implementation ProgressWindow

- (void)windowDidLoad {
    [super windowDidLoad];
    
    self.labelOperationDescription.stringValue = self.operationDescription;
    
    [self.progressBar startAnimation:nil];
}

@end
