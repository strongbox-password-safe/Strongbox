//
//  UpgradeWindowController.m
//  MacBox
//
//  Created by Mark on 22/08/2017.
//  Copyright © 2017 Mark McGuill. All rights reserved.
//

#import "UpgradeWindowController.h"
#import "Alerts.h"

@interface UpgradeWindowController ()

@property (nonatomic, strong) SKProduct *product;
@property (nonatomic) NSInteger cancelDelay;

@end

@implementation UpgradeWindowController

+ (BOOL)run:(SKProduct*)product cancelDelay:(NSInteger)cancelDelay
{
    UpgradeWindowController* windowController = [[UpgradeWindowController alloc] initWithWindowNibName:@"UpgradeWindowController"];
    windowController.product = product;
    windowController.cancelDelay = cancelDelay;
    
    if ([NSApp runModalForWindow:windowController.window]) {
        return YES; 
    }
    
    return NO;
}

- (void)close:(BOOL)ret {
    [[SKPaymentQueue defaultQueue] removeTransactionObserver:self];
    
    [NSApp stopModalWithCode:ret];
    [self.window close];
}

- (void)windowDidLoad {
    [super windowDidLoad];
    
    [self.window center];
    
    self.buttonUpgrade.layer.cornerRadius = 25;
    
    [[SKPaymentQueue defaultQueue] addTransactionObserver:self];
    
    if(self.cancelDelay > 0) {
        [self.buttonNoThanks setEnabled:NO];
        [self.buttonNoThanks setTitle:[NSString stringWithFormat:@"No Thanks (%ld)", (long)self.cancelDelay]];

        __block NSInteger secondsRemaining = self.cancelDelay;
        NSTimer *y = [NSTimer scheduledTimerWithTimeInterval:1.0f repeats:YES block:^(NSTimer * _Nonnull timer) {
            //NSLog(@"timer: %ld", (long)secondsRemaining);
        
            secondsRemaining--;
            
            if(secondsRemaining < 1) {
                [self.buttonNoThanks setTitle:@"No Thanks"];
                [timer invalidate];
            }
            else {
                [self.buttonNoThanks setTitle:[NSString stringWithFormat:@"No Thanks (%ld)", (long)secondsRemaining]];
            }
        }];

        [[NSRunLoop currentRunLoop] addTimer:y forMode:NSModalPanelRunLoopMode];
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, self.cancelDelay * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
            [self.buttonNoThanks setEnabled:YES];
        });
    }
}

- (IBAction)onNoThanks:(id)sender {
    [self close:NO];
}

- (IBAction)onPurchase:(id)sender {
    if ([SKPaymentQueue canMakePayments]) {
        
        //[SVProgressHUD showWithStatus:@"Purchasing..."];
        SKPayment *payment = [SKPayment paymentWithProduct:self.product];
        [[SKPaymentQueue defaultQueue] addPayment:payment];
    }
    else{
        [Alerts info:@"Purchases Are Disabled on Your Device." window:self.window];
    }
}

- (IBAction)onRestore:(id)sender {
    //    self.buttonRestore.enabled = NO;
    //    
    //    [SVProgressHUD showWithStatus:@"Restoring..."];
    
    [[SKPaymentQueue defaultQueue] restoreCompletedTransactions];
}

#pragma mark StoreKit Delegate

- (void)paymentQueue:(SKPaymentQueue *)queue restoreCompletedTransactionsFailedWithError:(NSError *)error {
    NSLog(@"restoreCompletedTransactionsFailedWithError: %@", error);
    
    //[SVProgressHUD popActivity];
    //self.buttonRestore.enabled = YES;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [Alerts error:@"" error:error window:self.window completion:^{
            [self close:NO];
        }];
    });
 }

- (void)paymentQueueRestoreCompletedTransactionsFinished:(SKPaymentQueue *)queue {
    NSLog(@"paymentQueueRestoreCompletedTransactionsFinished: %@", queue);
    
    //[SVProgressHUD popActivity];
    
    if(queue.transactions.count == 0) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [Alerts info:@"Restoration Unsuccessful"
         informativeText:@"Could not find any previously purchased products."
                  window:self.window
              completion:^{
                    [self close:NO];
                  }];
        });
    }
    else {
        dispatch_async(dispatch_get_main_queue(), ^{
            [Alerts info:@"Welcome back to StrongBox"
         informativeText:@"Upgrade Restored Successfully. Thank you for your support!"
                  window:self.window
              completion:^{
                [self close:YES];
            }];
        });
    }
}

-(void)paymentQueue:(SKPaymentQueue *)queue
updatedTransactions:(NSArray *)transactions {
    for (SKPaymentTransaction *transaction in transactions) {
        switch (transaction.transactionState) {
            case SKPaymentTransactionStatePurchasing:
                NSLog(@"Purchasing");
                break;
            case SKPaymentTransactionStatePurchased:
            {
                [[SKPaymentQueue defaultQueue] finishTransaction:transaction];
                
                //[SVProgressHUD popActivity];
                
                dispatch_async(dispatch_get_main_queue(), ^{
                    [Alerts info:@"Welcome to StrongBox"
                 informativeText:@"Upgrade to Full version successful! Thank you for your support!"
                          window:self.window  completion:^{
                        [self close:YES];
                    }];
                });
            }
                break;
            case SKPaymentTransactionStateRestored:
            {
                NSLog(@"updatedTransactions: Restored");
                [[SKPaymentQueue defaultQueue] finishTransaction:transaction];
            }
                break;
            case SKPaymentTransactionStateFailed:
            {
                [[SKPaymentQueue defaultQueue] finishTransaction:transaction];
                NSLog(@"Purchase failed %@", transaction.error);
                
                dispatch_async(dispatch_get_main_queue(), ^{
                    [Alerts error:@"Failed to Upgrade" error:transaction.error window:self.window completion:^{
                        [self close:NO];
                    }];
                });
             }
                break;
            default:
                break;
        }
    }
}

@end
