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

static NSString* kFontName =  @"Futura-Bold";

typedef NS_ENUM (unsigned int, StoreRequestState) {
    kInitial,
    kWaitingForResponse,
    kSuccess,
    kFailed,
};

@interface UpgradeViewController ()

@property (nonatomic, strong) SKProductsRequest *productsRequest;
@property (nonatomic, strong) SKProduct *product;
@property (nonatomic) StoreRequestState storeRequestState;

@property (nonatomic, strong) NSDictionary* upgradeButtonTitleAttributes;
@property (nonatomic, strong) NSDictionary* upgradeButtonSubtitleAttributes;

@end

@implementation UpgradeViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.storeRequestState = kWaitingForResponse;
    
    NSSet *productIdentifiers = [NSSet setWithObjects:kIapProId, nil];
    self.productsRequest = [[SKProductsRequest alloc] initWithProductIdentifiers:productIdentifiers];
    self.productsRequest.delegate = self;
    [self.productsRequest start];
    
    [self initializeUi];
    
    [self updateUi];
    
    [[SKPaymentQueue defaultQueue] addTransactionObserver:self];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    [self.navigationController setNavigationBarHidden:YES];
    
    self.navigationController.toolbarHidden = YES;
    self.navigationController.toolbar.hidden = YES;
}

- (IBAction)onNope:(id)sender {
    [self.navigationController popToRootViewControllerAnimated:YES];
}

- (void)viewWillDisappear:(BOOL)animated {
    if(self.productsRequest) {
        [self.productsRequest cancel];
        self.productsRequest = nil;
        self.storeRequestState = kInitial;
    }
    
    [[SKPaymentQueue defaultQueue] removeTransactionObserver:self];
    
    [super viewWillDisappear:animated];
}

-(void)productsRequest:(SKProductsRequest *)request
    didReceiveResponse:(SKProductsResponse *)response
{
    NSUInteger count = [response.products count];
    self.productsRequest = nil;
    
    if (count > 0) {
        //        for (SKProduct *validProduct in self.validProducts) {
        //            NSLog(@"%@", validProduct.productIdentifier);
        //            NSLog(@"%@", validProduct.localizedTitle);
        //            NSLog(@"%@", validProduct.localizedDescription);
        //            NSLog(@"%@", validProduct.price);
        //        }
        
        self.product = [response.products objectAtIndex:0];
        self.storeRequestState = kSuccess;
    }
    else {
        self.storeRequestState = kFailed;
    }
    
    [self updateUi];
}

- (void)initializeUi {
    self.labelBiometricIdFeature.text = [NSString stringWithFormat:@"Open with %@", [[Settings sharedInstance] getBiometricIdName]];
    
    UIColor *lemonColor = [[UIColor alloc] initWithRed:255/255 green:255/255 blue:0/255 alpha:1]; // select needed color

    self.upgradeButtonTitleAttributes = [self getAttributedTextDictionaryWithFontSize:32.0f foregroundColor:[UIColor whiteColor]];
    self.upgradeButtonSubtitleAttributes = [self getAttributedTextDictionaryWithFontSize:16.0f foregroundColor:lemonColor];
    
    self.buttonUpgrade2.layer.cornerRadius = 25;
    [self.buttonNope setHidden:YES];
    [self.buttonNope setEnabled:NO];
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1.5 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        [self.buttonNope setHidden:NO];
        [self.buttonNope setEnabled:YES];
    });
}

- (NSDictionary*)getAttributedTextDictionaryWithFontSize:(CGFloat)fontSize foregroundColor:(UIColor*)foregroundColor {
    NSMutableParagraphStyle *style = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
    [style setParagraphSpacing:4.0f];
    [style setAlignment:NSTextAlignmentCenter];
    [style setLineBreakMode:NSLineBreakByWordWrapping];
    
    UIFont *font = [UIFont fontWithName:kFontName size:fontSize];
    
    NSDictionary *dict3;
    if(font) {
        dict3 = @{NSUnderlineStyleAttributeName:@(NSUnderlineStyleNone),
                  NSFontAttributeName:font,
                  NSForegroundColorAttributeName: foregroundColor,
                  NSParagraphStyleAttributeName:style}; // Added line
    }
    else {
        dict3 = @{NSUnderlineStyleAttributeName:@(NSUnderlineStyleNone),
                  NSForegroundColorAttributeName: foregroundColor,
                  NSParagraphStyleAttributeName:style}; // Added line
    }
    
    return dict3;
}

- (NSString *)getPriceTextFromProduct {
    NSNumberFormatter* formatter = [[NSNumberFormatter alloc] init];
    formatter.numberStyle = NSNumberFormatterCurrencyStyle;
    formatter.locale = self.product.priceLocale;
    NSString* localCurrency = [formatter stringFromNumber:self.product.price];
    NSString* priceText = [NSString stringWithFormat:@"(%@)*", localCurrency];
    return priceText;
}

- (void)updateUi {
    if(self.storeRequestState == kWaitingForResponse) {
        NSAttributedString *attString = [[NSAttributedString alloc]
                                         initWithString:@"Contacting App Store... Please Wait..."
                                         attributes:self.upgradeButtonSubtitleAttributes];
        
        [self.buttonUpgrade2 setAttributedTitle:attString forState:UIControlStateNormal];
        [self.buttonUpgrade2 setEnabled:NO];
    }
    else if(self.storeRequestState == kSuccess) {
        NSString * priceText = [self getPriceTextFromProduct];
        
        NSMutableAttributedString *attString = [[NSMutableAttributedString alloc] init];
        [attString appendAttributedString:[[NSAttributedString alloc] initWithString:@"Upgrade\n"
                                                                          attributes:self.upgradeButtonTitleAttributes]];
        [attString appendAttributedString:[[NSAttributedString alloc] initWithString:priceText
                                                                          attributes:self.upgradeButtonSubtitleAttributes]];
        
        [self.buttonUpgrade2 setAttributedTitle:attString forState:UIControlStateNormal];
        [[self.buttonUpgrade2 titleLabel] setNumberOfLines:2];
        [[self.buttonUpgrade2 titleLabel] setLineBreakMode:NSLineBreakByWordWrapping];
        [self.buttonUpgrade2 setEnabled:YES];
    }
    else {
        NSAttributedString *attString = [[NSAttributedString alloc]
                                                initWithString:@"Upgrade Momentarily Unavailable\nPlease Try Again Later" attributes:self.upgradeButtonSubtitleAttributes];
        
        [self.buttonUpgrade2 setAttributedTitle:attString forState:UIControlStateNormal];
        [self.buttonUpgrade2 setEnabled:NO];
    }
}

- (IBAction)onUpgrade:(id)sender {
    if( self.storeRequestState != kSuccess || self.product == nil) {
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
        // FUTURE: if multiple IAP - we need to check the product id is in the transactions queue
        
        [[Settings sharedInstance] setPro:YES];

        dispatch_async(dispatch_get_main_queue(), ^(void) {
            [self.navigationController popToRootViewControllerAnimated:YES];
        });
        
//        [Alerts info:self title:@"Welcome Back to Strongbox Pro" message:@"Upgrade Restored Successfully. Thank you!" completion:^{
//            [self.navigationController popToRootViewControllerAnimated:YES];
//        }];
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
                
//                [Alerts info:self title:@"Welcome to Strongbox Pro" message:@"Upgrade successful" completion:^{
                dispatch_async(dispatch_get_main_queue(), ^(void) {
                    [self.navigationController popToRootViewControllerAnimated:YES];
                });
//                }];

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
