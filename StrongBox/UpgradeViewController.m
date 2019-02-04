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
#import <StoreKit/StoreKit.h>

static NSString* const kIapProId =  @"com.markmcguill.strongbox.pro";
static NSString* const kMonthly =  @"com.strongbox.markmcguill.upgrade.pro.monthly";
static NSString* const k3Monthly =  @"com.strongbox.markmcguill.upgrade.pro.3monthly";
static NSString* const kYearly =  @"com.strongbox.markmcguill.upgrade.pro.yearly";
//kTestConsumable @"com.markmcguill.strongbox.testconsumable"

static NSString* const kFontName =  @"Futura-Bold";

typedef NS_ENUM (unsigned int, StoreRequestState) {
    kInitial,
    kWaitingForResponse,
    kSuccess,
    kFailed,
};

@interface UpgradeViewController () <SKPaymentTransactionObserver, SKProductsRequestDelegate>

@property (nonatomic) StoreRequestState storeRequestState;

@property (nonatomic, strong) SKProductsRequest *productsRequest;
@property (nonatomic, strong) NSMutableDictionary<NSString*, SKProduct *> *products;

@property (nonatomic, strong) NSDictionary* upgradeButtonTitleAttributes;
@property (nonatomic, strong) NSDictionary* upgradeButtonSubtitleAttributes;

@end

@implementation UpgradeViewController

// TODO: Lock this view or have it work ok in all orientations

//- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
//    return UIInterfaceOrientationMaskPortrait;
//}
//
//- (BOOL)shouldAutorotate {
//    return NO;
//}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.storeRequestState = kWaitingForResponse;
    self.products = nil;
    
    NSSet *productIdentifiers = [NSSet setWithArray:@[kIapProId, kMonthly, k3Monthly, kYearly]];
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

- (void)initializeUi {
    self.labelBiometricIdFeature.text = [NSString stringWithFormat:@"Open with %@", [[Settings sharedInstance] getBiometricIdName]];
    
    UIColor *lemonColor = [[UIColor alloc] initWithRed:255/255 green:255/255 blue:0/255 alpha:1]; // select needed color
    
    self.upgradeButtonTitleAttributes = [self getAttributedTextDictionaryWithFontSize:32.0f foregroundColor:[UIColor whiteColor]];
    self.upgradeButtonSubtitleAttributes = [self getAttributedTextDictionaryWithFontSize:16.0f foregroundColor:lemonColor];
    
    self.buttonUpgrade2.layer.cornerRadius = 25;
    //[self.buttonNope setHidden:YES];
    [self.buttonNope setEnabled:NO];
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1.5 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        //[self.buttonNope setHidden:NO];
        [self.buttonNope setEnabled:YES];
    });
    
    self.sub1View.layer.cornerRadius = 15;
    self.sub2View.layer.cornerRadius = 15;
    self.sub3View.layer.cornerRadius = 15;
    self.sub4View.layer.cornerRadius = 15;

//    self.comparisonChartStackView.layer.borderWidth = 1;
//    self.comparisonChartStackView.layer.borderColor = [[UIColor lightGrayColor] CGColor];
//    
//    self.scollViewComparisonChart.layer.borderWidth = 1;
//    self.scollViewComparisonChart.layer.borderColor =[[UIColor lightGrayColor] CGColor];
//    self.scollViewComparisonChart.layer.cornerRadius = 2;
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

-(void)productsRequest:(SKProductsRequest *)request
    didReceiveResponse:(SKProductsResponse *)response
{
    self.products = [NSMutableDictionary dictionary];
    if (response.products.count > 0) {
        for (SKProduct *validProduct in response.products) {
            NSLog(@"%@", validProduct.productIdentifier);
            NSLog(@"%@", validProduct.localizedTitle);
            NSLog(@"%@", validProduct.localizedDescription);
            NSLog(@"%@", validProduct.price);
            
            [self.products setValue:validProduct forKey:validProduct.productIdentifier];
        }
        
        self.storeRequestState = kSuccess;
    }
    else {
        self.storeRequestState = kFailed;
    }
    
    [self updateUi];
}

- (NSString *)getPriceTextFromProduct:(SKProduct*)product {
    NSNumberFormatter* formatter = [[NSNumberFormatter alloc] init];
    formatter.numberStyle = NSNumberFormatterCurrencyStyle;
    formatter.locale = product.priceLocale;
    NSString* localCurrency = [formatter stringFromNumber:product.price];
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
        SKProduct* product = self.products[kIapProId]; // TODO: Do this for other options? Also, check key exists - product may not be available... 
        NSString * priceText = [self getPriceTextFromProduct:product];
        
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
    if( self.storeRequestState != kSuccess || self.products == nil || self.products.count == 0) {
        [Alerts warn:self
               title:@"Product Error"
             message:@"Could not access Upgrade Products on App Store. Please try again later."];
    }
    else {
        if ([SKPaymentQueue canMakePayments]) {
            [SVProgressHUD showWithStatus:@"Purchasing..."];
            _buttonUpgrade2.enabled = NO;
            _buttonRestore.enabled = NO;
            _buttonNope.enabled = NO;
            
            SKProduct* product = self.products[kIapProId]; // TODO: Do this for other options?
            SKPayment *payment = [SKPayment paymentWithProduct:product];
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

        dispatch_async(dispatch_get_main_queue(), ^(void) {
            [self.navigationController popToRootViewControllerAnimated:YES];
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
                // TODO: if multiple IAP - we need to check the product id is in the transactions queue

                [[Settings sharedInstance] setPro:YES];
                [[SKPaymentQueue defaultQueue] finishTransaction:transaction];
                
                _buttonUpgrade2.enabled = YES;
                _buttonRestore.enabled = YES;
                _buttonNope.enabled = YES;
            
                [SVProgressHUD dismiss];
                
                dispatch_async(dispatch_get_main_queue(), ^(void) {
                    [self.navigationController popToRootViewControllerAnimated:YES];
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
