//
//  EnableSystemAutoFillInstructionsViewController.m
//  MacBox
//
//  Created by Strongbox on 25/09/2022.
//  Copyright © 2022 Mark McGuill. All rights reserved.
//

#import "EnableSystemAutoFillInstructionsViewController.h"
#import <AuthenticationServices/AuthenticationServices.h>
#import "SBLog.h"

@interface EnableSystemAutoFillInstructionsViewController ()<NSPopoverDelegate>

@property BOOL oneTimeIgnoreDismissal;

@property (weak) IBOutlet NSTextField *old1;
@property (weak) IBOutlet NSTextField *old2;
@property (weak) IBOutlet NSTextField *old3;
@property (weak) IBOutlet NSButton *oldButton;

@property (weak) IBOutlet NSTextField *updatedAlternative;
@property (weak) IBOutlet NSButton *updatedButton;
@property (weak) IBOutlet NSTextField *updated1;
@property (weak) IBOutlet NSTextField *updated2;
@property (weak) IBOutlet NSTextField *updated3;
@property (weak) IBOutlet NSTextField *updated4;
@property (weak) IBOutlet NSStackView *stackViewNewButton;

@end

@implementation EnableSystemAutoFillInstructionsViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    if (@available(macOS 14.0, *)) {
        self.old1.hidden = YES;
        self.old2.hidden = YES;
        self.old3.hidden = YES;
        self.oldButton.hidden = YES;
    }
    else {
        self.updated1.hidden = YES;
        self.updated2.hidden = YES;
        self.updated3.hidden = YES;
        self.updated4.hidden = YES;

        self.stackViewNewButton.hidden = YES;
    }
}

- (IBAction)onOpenExtensions:(id)sender {
    self.oneTimeIgnoreDismissal = YES;
    
    if (@available(macOS 14.0, *)) {
        [ASSettingsHelper openCredentialProviderAppSettingsWithCompletionHandler:^(NSError * _Nullable error) {
            slog(@"Done opening Cred Provider - %@", error);
        }];
    } else {
        [NSWorkspace.sharedWorkspace openURL:[NSURL fileURLWithPath:@"/System/Library/PreferencePanes/Extensions.prefPane"]];
    }

}

- (BOOL)popoverShouldClose:(NSPopover *)popover {
    if ( self.oneTimeIgnoreDismissal ) {
        self.oneTimeIgnoreDismissal = NO;
        return NO;
    }
    
    return YES;
}

@end
