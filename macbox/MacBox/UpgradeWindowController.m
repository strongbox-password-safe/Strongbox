//
//  UpgradeWindowController.m
//  MacBox
//
//  Created by Mark on 22/08/2017.
//  Copyright © 2017 Mark McGuill. All rights reserved.
//

#import "UpgradeWindowController.h"
#import "MacAlerts.h"
#import "Settings.h"

//#define kFontName @"Futura-Bold"

@interface UpgradeWindowController () // Remove this class completely? We can't actually - too many existing customers


@property (nonatomic) NSInteger cancelDelay;
@property (nonatomic) BOOL isPurchasing;

@property NSInteger secondsRemaining;
@property NSTimer *countdownTimer;

@property (weak) IBOutlet NSButton *buttonNoThanks;
@property (weak) IBOutlet NSButton *buttonUpgrade;
@property (weak) IBOutlet NSProgressIndicator *progressIndicator;

@end

@implementation UpgradeWindowController

static UpgradeWindowController *sharedInstance = nil;

+ (void)show:(NSInteger)cancelDelay {
    if (!sharedInstance) {
        sharedInstance = [[UpgradeWindowController alloc] initWithWindowNibName:@"UpgradeWindowController"];

        sharedInstance.cancelDelay = cancelDelay;
    }
 
    [sharedInstance showWindow:nil];
}

- (void)windowWillClose:(NSNotification *)notification {
    if ([notification object] == [self window] && self == sharedInstance) {
        sharedInstance = nil;
    }
}

- (void)close:(BOOL)ret {
    [[SKPaymentQueue defaultQueue] removeTransactionObserver:self];
    
    if(ret) {
        [Settings.sharedInstance setPro:YES];
    }
    
    [self.window close];
}

- (void)cancel:(id)sender { 
    if (self.cancelDelay == 0) {
        [self close];
    }
}

- (void)windowDidLoad {
    [super windowDidLoad];

    [self.window makeKeyAndOrderFront:nil];
    [self.window center];
    [self.window setLevel:NSModalPanelWindowLevel]; 
    [self.window setHidesOnDeactivate:YES];
    

    
    [[SKPaymentQueue defaultQueue] addTransactionObserver:self];
    
    if(self.cancelDelay > 0) {
        [self startNoThanksCountdown];
    }
}

- (void)startNoThanksCountdown {
    slog(@"Starting No Thanks Countdown with %ld delay", (long)self.cancelDelay);
    
    [self.buttonNoThanks setEnabled:NO];
    
    NSString* loc = NSLocalizedString(@"mac_upgrade_no_thanks_seconds_remaining_fmt", @"No Thanks (%ld)");
    [self.buttonNoThanks setTitle:[NSString stringWithFormat:loc, (long)self.cancelDelay]];

    if(self.countdownTimer) {
        [self.countdownTimer invalidate];
    }
    self.secondsRemaining = self.cancelDelay;
    self.countdownTimer = [NSTimer scheduledTimerWithTimeInterval:1.0f
                                     target:self
                                selector:@selector(updateNoThanksCountdown)
                                   userInfo:nil
                                    repeats:YES];

    [[NSRunLoop currentRunLoop] addTimer:self.countdownTimer forMode:NSModalPanelRunLoopMode];
}

- (void)updateNoThanksCountdown {

    self.secondsRemaining--;

    if(self.secondsRemaining < 1) {
        NSString* loc = NSLocalizedString(@"mac_upgrade_no_thanks", @"No Thanks");

        [self.buttonNoThanks setTitle:loc];
        [self.buttonNoThanks setEnabled:YES];
        [self.countdownTimer invalidate];
        self.countdownTimer = nil;
    }
    else {
        NSString* loc = NSLocalizedString(@"mac_upgrade_no_thanks_seconds_remaining_fmt", @"No Thanks (%ld)");
        [self.buttonNoThanks setTitle:[NSString stringWithFormat:loc, (long)self.secondsRemaining]];
    }
}

- (void)showProgressIndicator {
    NSView *superView = self.progressIndicator.superview;
    [self.progressIndicator removeFromSuperview];
    [superView addSubview:self.progressIndicator];
    [self.progressIndicator startAnimation:self];
}

- (IBAction)onNoThanks:(id)sender {
    [self close:NO];
}

- (IBAction)onPurchase:(id)sender {
    [MacAlerts twoOptionsWithCancel:NSLocalizedString(@"upgrade_vc_old_freemium_upgrade_options_title", @"Strongbox Upgrade Options")
                    informativeText:NSLocalizedString(@"upgrade_vc_strongbox_unified_message", @"Strongbox is now available for both iOS and macOS as a unified App.\n\nIf you have already purchased Strongbox then click 'Restore' below.\n\nIf you are new and want to Upgrade, the best way to do that is via the unified Strongbox app. Click 'View Strongbox Unified App' below to view on the App Store.")
                  option1AndDefault:NSLocalizedString(@"upgrade_vc_old_freemium_upgrade_view_unified", @"View Strongbox Unified")
                            option2:NSLocalizedString(@"upgrade_vc_old_freemium_upgrade_restore_pro", @"Restore my Pro Purchase")
                             window:self.window
                         completion:^(int response) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if ( response == 0 ) {
                [NSWorkspace.sharedWorkspace openURL:[NSURL URLWithString:@"itms-apps:
                [self onNoThanks:nil];
            }
            else if ( response == 1 ) {
                [self onRestore:nil];
            }
        });
    }];
}

- (IBAction)onRestore:(id)sender {
    self.isPurchasing = NO;
    self.buttonUpgrade.enabled = NO;
    self.buttonNoThanks.enabled = NO;
    [self showProgressIndicator];

    [[SKPaymentQueue defaultQueue] restoreCompletedTransactions];    
}

#pragma mark StoreKit Delegate

- (void)paymentQueue:(SKPaymentQueue *)queue restoreCompletedTransactionsFailedWithError:(NSError *)error {
    slog(@"restoreCompletedTransactionsFailedWithError: %@", error);
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [MacAlerts error:@"Error in restoreCompletedTransactionsFailedWithError" error:error window:self.window completion:^{
            [self close:NO];
        }];
    });
 }

- (void)paymentQueueRestoreCompletedTransactionsFinished:(SKPaymentQueue *)queue {
    slog(@"paymentQueueRestoreCompletedTransactionsFinished: %@", queue);
    
    if(queue.transactions.count == 0) {
        dispatch_async(dispatch_get_main_queue(), ^{
            NSString* loc = NSLocalizedString(@"mac_upgrade_restoration_unsuccessful", @"Restoration Unsuccessful");
            NSString* loc2 = NSLocalizedString(@"mac_upgrade_could_not_find_any_previous_purchases", @"Could not find any previously purchased products.");

            [MacAlerts info:loc
         informativeText:loc2
                  window:self.window
              completion:^{
                    [self close:NO];
                  }];
        });
    }
    else {
        [self onSuccessfulRestore];
    }
}

- (void)onSuccessfulRestore {
    dispatch_async(dispatch_get_main_queue(), ^{
        NSString* loc = NSLocalizedString(@"mac_upgrade_welcome_back_to_strongbox", @"Welcome back to Strongbox Pro");
        NSString* loc2 = NSLocalizedString(@"mac_upgrade_upgrade_restored_success", @"Upgrade Restored Successfully. Thank you for your support!\n\n"
        @"Please restart the Application to enjoy your Pro features.");

        [MacAlerts info:loc
     informativeText:loc2
              window:self.window
          completion:^{
              [self close:YES];
          }];
    });
}

-(void)paymentQueue:(SKPaymentQueue *)queue
updatedTransactions:(NSArray *)transactions {
    for (SKPaymentTransaction *transaction in transactions) {
        switch (transaction.transactionState) {
            case SKPaymentTransactionStatePurchasing:
                slog(@"Purchasing");
                break;
            case SKPaymentTransactionStatePurchased:
            {
                [[SKPaymentQueue defaultQueue] finishTransaction:transaction];

                NSString* loc = NSLocalizedString(@"mac_upgrade_welcome_to_strongbox", @"Welcome to Strongbox Pro");
                NSString* loc2 = NSLocalizedString(@"mac_upgrade_upgrade_successful_thank_you", @"Upgrade to Pro version successful! Thank you for your support!\n\nPlease restart the Application to enjoy your Pro features.");

                dispatch_async(dispatch_get_main_queue(), ^{
                    [MacAlerts info:loc
                 informativeText:loc2
                          window:self.window  completion:^{
                        [self close:YES];
                    }];
                });
            }
                break;
            case SKPaymentTransactionStateRestored:
            {
                slog(@"updatedTransactions: Restored");
                [[SKPaymentQueue defaultQueue] finishTransaction:transaction];
                
                if(self.isPurchasing) {
                    [self onSuccessfulRestore];
                }
            }
                break;
            case SKPaymentTransactionStateFailed:
            {
                slog(@"Purchase failed %@", transaction.error);
                
                [[SKPaymentQueue defaultQueue] finishTransaction:transaction];
                
                dispatch_async(dispatch_get_main_queue(), ^{
                    NSString* loc = NSLocalizedString(@"mac_upgrade_failed_to_upgrade", @"Failed to Upgrade");

                    [MacAlerts error:loc
                            error:transaction.error
                           window:self.window
                       completion:^{
                        [self close:NO];
                    }];
                });
             }
                break;
            default:
                slog(@"Purchase State %ld", (long)transaction.transactionState);
                break;
        }
    }
}























































































































@end
