//
//  WindowController.m
//  MacBox
//
//  Created by Mark on 07/08/2017.
//  Copyright © 2017 Mark McGuill. All rights reserved.
//

#import "WindowController.h"
#import "Settings.h"
#import "Document.h"
#import "ViewController.h"

@interface WindowController ()

@end

@implementation WindowController

- (void)windowDidLoad {
    [super windowDidLoad];
    
    NSLog(@"WindowController::windowDidLoad [%@]", self.document);
    
    self.shouldCascadeWindows = YES;
    
    
    
    self.windowFrameAutosaveName = @"strongbox-window-controller-autosave";
}

- (NSString*)windowTitleForDocumentDisplayName:(NSString *)displayName {
    Document* doc = (Document*)self.document;
    NSMutableArray* statusii = NSMutableArray.array;
    if ( doc.viewModel.offlineMode ) {
        [statusii addObject:NSLocalizedString(@"database_offline_mode_window_suffix", @"Offline")];
    }
    if ( doc.viewModel.isEffectivelyReadOnly ) {
        [statusii addObject:NSLocalizedString(@"databases_toggle_read_only_context_menu", @"Read-Only")];
    }

    NSString* statusSuffix = @"";
    if ( statusii.firstObject ) {
        NSString* statusiiStrings = [statusii componentsJoinedByString:@", "];
        statusSuffix = [NSString stringWithFormat:@" (%@)", statusiiStrings];
    }
    
    NSString* freeTrialSuffix = @"";
    if(![Settings sharedInstance].fullVersion) {
        if (![Settings sharedInstance].freeTrial) {
            NSString* loc = NSLocalizedString(@"mac_free_trial_window_title_suffix", @" - (Pro Upgrade Available)");
            freeTrialSuffix = loc;
        }
        else {
            long daysLeft = (long)[Settings sharedInstance].freeTrialDaysRemaining;

            if(daysLeft < 1 || daysLeft > 88) {
                NSString* loc = NSLocalizedString(@"mac_free_trial_window_title_suffix", @" - (Pro Upgrade Available)");
                freeTrialSuffix = loc;
            }
            else {
                NSString* loc = NSLocalizedString(@"mac_pro_days_left_window_title_suffix_fmt", @" - [%ld Pro Days Left]");
                freeTrialSuffix = [NSString stringWithFormat:loc, daysLeft];
            }
        }
    }










    return [NSString stringWithFormat:@"%@%@%@", displayName, statusSuffix, freeTrialSuffix];
}

- (void)setDocument:(id)document {
    [super setDocument:document];
    
    NSLog(@"WindowController::setDocument [%@] - [%@]", self.document, self.contentViewController);
    
    
    
    
    
    if ( self.contentViewController && [self.contentViewController isKindOfClass:ViewController.class] ) {
        ViewController* vc = (ViewController*)self.contentViewController;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.01 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [vc onDocumentLoaded];
        });
    }
}

@end
