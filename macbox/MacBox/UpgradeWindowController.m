//
//  UpgradeWindowController.m
//  MacBox
//
//  Created by Mark on 22/08/2017.
//  Copyright © 2017 Mark McGuill. All rights reserved.
//

#import "UpgradeWindowController.h"
#import "Alerts.h"

#define kFontName @"Futura-Bold"

@interface UpgradeWindowController ()

@property (nonatomic, strong) SKProduct *product;
@property (nonatomic) NSInteger cancelDelay;
@property (nonatomic) BOOL isPurchasing;

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
    
    [self customizeButtonsBasedOnProduct];
    
    [[SKPaymentQueue defaultQueue] addTransactionObserver:self];
    
    if(self.cancelDelay > 0) {
        [self startNoThanksCountdown];
    }
}

- (NSString*)getPriceTextFromProduct {
    NSNumberFormatter* formatter = [[NSNumberFormatter alloc] init];
    formatter.numberStyle = NSNumberFormatterCurrencyStyle;
    formatter.locale = self.product.priceLocale;
    NSString* localCurrency = [formatter stringFromNumber:self.product.price];
    return [NSString stringWithFormat:@"(%@)*", localCurrency];
}

- (void) customizeButtonsBasedOnProduct {
    self.buttonUpgrade.layer.cornerRadius = 15;
    
    NSMutableParagraphStyle *style = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
    [style setParagraphSpacing:1.0f];
    [style setAlignment:NSTextAlignmentCenter];
    [style setLineBreakMode:NSLineBreakByWordWrapping];
    
    NSFont *font1 = [NSFont fontWithName:kFontName size:32.0f];
    NSFont *font2 = [NSFont fontWithName:kFontName size:16.0f];
    
    NSColor *lemonColor = [NSColor colorWithRed:255/255 green:255/255 blue:0/255 alpha:1];
    
    NSDictionary *dict1;
    if(font1) {
        dict1 = @{NSUnderlineStyleAttributeName:@(NSUnderlineStyleNone),
                  NSFontAttributeName:font1,
                  NSForegroundColorAttributeName: [NSColor whiteColor],
                  NSParagraphStyleAttributeName:style}; // Added line
    }
    else {
        dict1 = @{NSUnderlineStyleAttributeName:@(NSUnderlineStyleNone),
                  NSForegroundColorAttributeName: [NSColor whiteColor],
                  NSParagraphStyleAttributeName:style}; // Added line
    }
    
    NSDictionary *dict2;
    if(font2) {
        dict2 = @{NSUnderlineStyleAttributeName:@(NSUnderlineStyleNone),
                  NSFontAttributeName:font2,
                  NSForegroundColorAttributeName: lemonColor,
                  NSParagraphStyleAttributeName:style}; // Added line
    }
    else {
        dict2 = @{NSUnderlineStyleAttributeName:@(NSUnderlineStyleNone),
                  NSForegroundColorAttributeName: lemonColor,
                  NSParagraphStyleAttributeName:style}; // Added line
    }
    
    if(self.product != nil) {
        NSMutableAttributedString *attString = [[NSMutableAttributedString alloc] init];
        [attString appendAttributedString:[[NSAttributedString alloc] initWithString:@"Upgrade\n" attributes:dict1]];
        
        NSString* priceText = [self getPriceTextFromProduct];
        [attString appendAttributedString:[[NSAttributedString alloc] initWithString:priceText attributes:dict2]];
        
        self.buttonUpgrade.enabled = YES;
        self.buttonRestore.enabled = YES;
        self.buttonUpgrade.stringValue = attString.string;
        
        [self.buttonUpgrade setAttributedTitle:attString];
        //[[self.buttonUpgrade titleLabel] setNumberOfLines:2];
        //[[self.buttonUpgrade titleLabel] setLineBreakMode:NSLineBreakByWordWrapping];
    }
    else {
        NSFont *font3 = [NSFont fontWithName:kFontName size:16.0f];

        NSDictionary *dict3;
        if(font3) {
            dict3 = @{NSUnderlineStyleAttributeName:@(NSUnderlineStyleNone),
                      NSFontAttributeName:font3,
                      NSForegroundColorAttributeName: lemonColor,
                      NSParagraphStyleAttributeName:style}; // Added line
        }
        else {
            dict3 = @{NSUnderlineStyleAttributeName:@(NSUnderlineStyleNone),
                      NSForegroundColorAttributeName: lemonColor,
                      NSParagraphStyleAttributeName:style}; // Added line
        }

        NSMutableAttributedString *attString = [[NSMutableAttributedString alloc] init];
        [attString appendAttributedString:[[NSAttributedString alloc] initWithString:@"Upgrade Momentarily Unavailable"
                                           @"\nPlease Check Your Connection and Try Again Later"
                                                                          attributes:dict3]];
        [self.buttonUpgrade setAttributedTitle:attString];

        [self.buttonRestore setTitle:@"Restore Momentarily Unavailable"];
    
        self.buttonUpgrade.enabled = NO;
        self.buttonRestore.enabled = NO;
    }
}

- (void) startNoThanksCountdown {
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
    if ([SKPaymentQueue canMakePayments]) {
        self.isPurchasing = YES;
        self.buttonUpgrade.enabled = NO;
        self.buttonRestore.enabled = NO;
        self.buttonNoThanks.enabled = NO;
        [self.textViewDetails setTextColor: [NSColor disabledControlTextColor]];
        [self showProgressIndicator];
        
        SKPayment *payment = [SKPayment paymentWithProduct:self.product];
        [[SKPaymentQueue defaultQueue] addPayment:payment];
    }
    else{
        [Alerts info:@"Purchases Are Disabled on Your Device." window:self.window];
    }
}

- (IBAction)onRestore:(id)sender {
    self.isPurchasing = NO;
    self.buttonUpgrade.enabled = NO;
    self.buttonRestore.enabled = NO;
    self.buttonNoThanks.enabled = NO;
    [self.textViewDetails setTextColor: [NSColor disabledControlTextColor]];
    [self showProgressIndicator];

    [[SKPaymentQueue defaultQueue] restoreCompletedTransactions];
}

#pragma mark StoreKit Delegate

- (void)paymentQueue:(SKPaymentQueue *)queue restoreCompletedTransactionsFailedWithError:(NSError *)error {
    NSLog(@"restoreCompletedTransactionsFailedWithError: %@", error);
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [Alerts error:@"" error:error window:self.window completion:^{
            [self close:NO];
        }];
    });
 }

- (void)paymentQueueRestoreCompletedTransactionsFinished:(SKPaymentQueue *)queue {
    NSLog(@"paymentQueueRestoreCompletedTransactionsFinished: %@", queue);
    
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
        [self onSuccessfulRestore];
    }
}

- (void)onSuccessfulRestore {
    dispatch_async(dispatch_get_main_queue(), ^{
        [Alerts info:@"Welcome back to Strongbox Pro"
     informativeText:@"Upgrade Restored Successfully. Thank you for your support!\n\n"
         @"Please restart the Application to enjoy your Pro features."
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
                NSLog(@"Purchasing");
                break;
            case SKPaymentTransactionStatePurchased:
            {
                [[SKPaymentQueue defaultQueue] finishTransaction:transaction];
                
                dispatch_async(dispatch_get_main_queue(), ^{
                    [Alerts info:@"Welcome to Strongbox Pro"
                 informativeText:@"Upgrade to Pro version successful! Thank you for your support!\n\nPlease restart the Application to enjoy your Pro features."
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
                
                if(self.isPurchasing) {
                    [self onSuccessfulRestore];
                }
            }
                break;
            case SKPaymentTransactionStateFailed:
            {
                NSLog(@"Purchase failed %@", transaction.error);
                
                [[SKPaymentQueue defaultQueue] finishTransaction:transaction];
                
                dispatch_async(dispatch_get_main_queue(), ^{
                    [Alerts error:@"Failed to Upgrade" error:transaction.error window:self.window completion:^{
                        [self close:NO];
                    }];
                });
             }
                break;
            default:
                NSLog(@"Purchase State %ld", (long)transaction.transactionState);
                break;
        }
    }
}

@end
