//
//  UpgradeTableController.m
//  
//
//  Created by Mark on 16/07/2017.
//
//

#import "UpgradeViewController.h"
#import "Alerts.h"
#import "Settings.h"
#import "SVProgressHUD.h"

#define kFontName @"Futura-Bold"

@implementation UpgradeViewController

- (IBAction)onNope:(id)sender {
    [self dismissViewControllerAnimated:NO completion:nil];
}

- (void)viewWillDisappear:(BOOL)animated {
    [[SKPaymentQueue defaultQueue] removeTransactionObserver:self];

    [super viewWillDisappear:animated];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.buttonUpgrade2.layer.cornerRadius = 25;
    [self.buttonNope setHidden:YES];
    [self.buttonNope setEnabled:NO];
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1.5 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        [self.buttonNope setHidden:NO];
        [self.buttonNope setEnabled:YES];
    });
    
    NSNumberFormatter* formatter = [[NSNumberFormatter alloc] init];
    formatter.numberStyle = NSNumberFormatterCurrencyStyle;
    formatter.locale = self.product.priceLocale;
    NSString* localCurrency = [formatter stringFromNumber:self.product.price];
    NSString* priceText = [NSString stringWithFormat:@"(%@)*", localCurrency];
    
    NSMutableParagraphStyle *style = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
    [style setParagraphSpacing:4.0f];
    [style setAlignment:NSTextAlignmentCenter];
    [style setLineBreakMode:NSLineBreakByWordWrapping];
    
    UIFont *font1 = [UIFont fontWithName:kFontName size:32.0f];
    UIFont *font2 = [UIFont fontWithName:kFontName size:16.0f];
    
    UIColor *lemonColor = [[UIColor alloc] initWithRed:255/255 green:255/255 blue:0/255 alpha:1]; // select needed color
    
    NSDictionary *dict1;
    if(font1) {
        dict1 = @{NSUnderlineStyleAttributeName:@(NSUnderlineStyleNone),
                  NSFontAttributeName:font1,
                  NSForegroundColorAttributeName: [UIColor whiteColor],
                  NSParagraphStyleAttributeName:style}; // Added line
    }
    else {
        dict1 = @{NSUnderlineStyleAttributeName:@(NSUnderlineStyleNone),
                  NSForegroundColorAttributeName: [UIColor whiteColor],
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
        [attString appendAttributedString:[[NSAttributedString alloc] initWithString:priceText attributes:dict2]];
        
        [self.buttonUpgrade2 setAttributedTitle:attString forState:UIControlStateNormal];
        [[self.buttonUpgrade2 titleLabel] setNumberOfLines:2];
        [[self.buttonUpgrade2 titleLabel] setLineBreakMode:NSLineBreakByWordWrapping];
        }
    else {
        UIFont *font3 = [UIFont fontWithName:kFontName size:16.0f];
        
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
        [attString appendAttributedString:[[NSAttributedString alloc] initWithString:@"Upgrade Momentarily Unavailable\nPlease Try Again Later" attributes:dict3]];
        
        [self.buttonUpgrade2 setAttributedTitle:attString forState:UIControlStateNormal];
        [self.buttonUpgrade2 setEnabled:NO];

        [self.buttonRestore setEnabled:NO];
        [self.buttonRestore setTitleColor:[UIColor darkGrayColor] forState:UIControlStateNormal];
    }
    
    [[SKPaymentQueue defaultQueue] addTransactionObserver:self];
}

- (IBAction)onUpgrade:(id)sender {
    if( self.product == nil) {
        [Alerts warn:self
               title:@"Product Error"
             message:@"Could not access Upgrade Product on App Store. Please try again later."];
    }
    else {
        if ([SKPaymentQueue canMakePayments]) {
            [SVProgressHUD showWithStatus:@"Purchasing..."];
            _buttonUpgrade2.enabled = NO;
            _buttonRestore.enabled = NO;
            _buttonNope.enabled = NO;
            
            SKPayment *payment = [SKPayment paymentWithProduct:self.product];
            [[SKPaymentQueue defaultQueue] addPayment:payment];
        }
        else{
            [Alerts warn:self
                   title:@"Purchases Disabled"
                 message:@"Purchases are disabled on your device"];
        }
    }
}

- (IBAction)onRestore:(id)sender {
    _buttonUpgrade2.enabled = NO;
    _buttonRestore.enabled = NO;
    _buttonNope.enabled = NO;
    
    [SVProgressHUD showWithStatus:@"Restoring..."];
    [[SKPaymentQueue defaultQueue] restoreCompletedTransactions];
}

#pragma mark StoreKit Delegate

- (void)paymentQueue:(SKPaymentQueue *)queue restoreCompletedTransactionsFailedWithError:(NSError *)error {
    NSLog(@"restoreCompletedTransactionsFailedWithError: %@", error);
    
    [SVProgressHUD dismiss];
    
    _buttonUpgrade2.enabled = YES;
    _buttonRestore.enabled = YES;
    _buttonNope.enabled = YES;
    
    [Alerts error:self title:@"Issue Restoring Purchase" error:error];
}

- (void)paymentQueueRestoreCompletedTransactionsFinished:(SKPaymentQueue *)queue {
    NSLog(@"paymentQueueRestoreCompletedTransactionsFinished: %@", queue);
    
    [SVProgressHUD dismiss];
    _buttonUpgrade2.enabled = YES;
    _buttonRestore.enabled = YES;
    _buttonNope.enabled = YES;
    
    
    if(queue.transactions.count == 0) {
        [Alerts info:self title:@"Restoration Unsuccessful" message:@"Upgrade could not be restored from previous purchase. Are you sure you have purchased this item?" completion:nil];
    }
    else {
        // TODO: if multiple IAP - we need to check the product id is in the transactions queue
        
        [[Settings sharedInstance] setPro:YES];

        [Alerts info:self title:@"Welcome Back to Strongbox Pro" message:@"Upgrade Restored Successfully. Thank you!" completion:^{
            [self dismissViewControllerAnimated:NO completion:nil];
        }];
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
                [[Settings sharedInstance] setPro:YES];
                [[SKPaymentQueue defaultQueue] finishTransaction:transaction];
                
                _buttonUpgrade2.enabled = YES;
                _buttonRestore.enabled = YES;
                _buttonNope.enabled = YES;
            
                [SVProgressHUD dismiss];
                
                [Alerts info:self title:@"Welcome to Strongbox Pro" message:@"Upgrade successful" completion:^{
                    [self dismissViewControllerAnimated:NO completion:nil];
                }];

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
                
                [SVProgressHUD dismiss];
                _buttonUpgrade2.enabled = YES;
                _buttonRestore.enabled = YES;
                _buttonNope.enabled = YES;

                [Alerts error:self title:@"Failed to Upgrade" error:transaction.error];
            }
                break;
            default:
                break;
        }
    }
}

@end
