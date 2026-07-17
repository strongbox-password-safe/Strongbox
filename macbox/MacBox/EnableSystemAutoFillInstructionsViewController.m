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

    if (@available(macOS 26.0, *)) {
        [self applyMacOS26Instructions];
    }
    else if (@available(macOS 14.0, *)) {
        [self applyModernInstructions];
    }
    else {
        [self applyLegacyInstructions];
    }
}

- (void)applyLegacyInstructions {
    self.old1.hidden = NO;
    self.old2.hidden = NO;
    self.old3.hidden = NO;
    self.oldButton.hidden = NO;

    self.updated1.hidden = YES;
    self.updated2.hidden = YES;
    self.updated3.hidden = YES;
    self.updated4.hidden = YES;

    self.stackViewNewButton.hidden = YES;
}

- (void)applyModernInstructions {
    self.old1.hidden = YES;
    self.old2.hidden = YES;
    self.old3.hidden = YES;
    self.oldButton.hidden = YES;

    self.updated1.hidden = NO;
    self.updated2.hidden = NO;
    self.updated3.hidden = NO;
    self.updated4.hidden = NO;

    self.stackViewNewButton.hidden = NO;
}

- (void)applyMacOS26Instructions {
    [self applyModernInstructions];

    self.updated1.stringValue = NSLocalizedString(@"1. Click below to open System Settings", @"Mac AutoFill instructions - macOS 26 step 1");
    self.updated2.stringValue = NSLocalizedString(@"2. Go to General → Autofill & Passwords", @"Mac AutoFill instructions - macOS 26 step 2");
    self.updated3.stringValue = NSLocalizedString(@"3. Enable 'Autofill Passwords and Passkeys'", @"Mac AutoFill instructions - macOS 26 step 3");
    self.updated4.stringValue = NSLocalizedString(@"4. Enable 'Strongbox'", @"Mac AutoFill instructions - macOS 26 step 4");
    self.updatedAlternative.stringValue = NSLocalizedString(@"Alternatively, navigate to: Settings > General > Autofill & Passwords", @"Mac AutoFill instructions - macOS 26 alternative path");
    self.updatedButton.title = NSLocalizedString(@"Open 'Autofill & Passwords'", @"Mac AutoFill instructions - macOS 26 open button");
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
