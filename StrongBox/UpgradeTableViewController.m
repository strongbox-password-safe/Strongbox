//
//  UpgradeTableViewController.m
//  Strongbox
//
//  Created by Mark on 10/02/2019.
//  Copyright © 2019 Mark McGuill. All rights reserved.
//

#import "UpgradeTableViewController.h"
#import "ProUpgradeIAPManager.h"
#import "SVProgressHUD.h"
#import "Alerts.h"
#import "Settings.h"
#import "LicenceCodeManager.h"

static NSString* const kFontNameNoneBold =  @"Futura";
static NSString* const kFontName =  @"Futura-Bold";

@interface UpgradeTableViewController ()

@property (nonatomic, strong) NSDictionary* titleAttributes;
@property (nonatomic, strong) NSDictionary* subtitleAttributes;
@property (nonatomic, strong) NSDictionary* bonusTextAttributes;

@property (weak, nonatomic) IBOutlet UIButton *buttonNope;
@property (weak, nonatomic) IBOutlet UIButton *button1Month;
@property (weak, nonatomic) IBOutlet UIButton *button3Months;
@property (weak, nonatomic) IBOutlet UIButton *buttonYearly;
@property (weak, nonatomic) IBOutlet UIButton *buttonLifetime;
@property (weak, nonatomic) IBOutlet UIButton *buttonHaveLicenceCode;
@property (weak, nonatomic) IBOutlet UIButton *buttonRestorePrevious;
@property (weak, nonatomic) IBOutlet UILabel *labelBiometricIdFeature;

@end

@implementation UpgradeTableViewController

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self.navigationController setNavigationBarHidden:YES];
    
    self.navigationController.toolbarHidden = YES;
    self.navigationController.toolbar.hidden = YES;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    self.labelBiometricIdFeature.text = [NSString stringWithFormat:@"🗝 Open with %@", [[Settings sharedInstance] getBiometricIdName]];
    
    [self initializeUi];
    [self updateUi];
    
    ProUpgradeIAPManager.sharedInstance.productsAvailableNotify = ^{
        dispatch_async(dispatch_get_main_queue(), ^(void) {
            [self updateUi];
        });
    };
}

- (void)initializeUi {
    UIColor *lemonColor = [[UIColor alloc] initWithRed:255/255 green:255/255 blue:0/255 alpha:1]; // select needed color
    
    self.titleAttributes = [self getAttributedTextDictionaryWithFontSize:20.0f foregroundColor:[UIColor whiteColor]];
    self.subtitleAttributes = [self getAttributedTextDictionaryWithFontSize:16.0f foregroundColor:lemonColor bold:NO];
    self.bonusTextAttributes = [self getAttributedTextDictionaryWithFontSize:14.0f foregroundColor:[UIColor greenColor] bold:NO];
    
    self.button1Month.layer.cornerRadius = 25;
    self.button3Months.layer.cornerRadius = 25;
    self.buttonYearly.layer.cornerRadius = 25;
    self.buttonLifetime.layer.cornerRadius = 25;

//    [self.buttonNope setEnabled:NO];
    
//    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1.5 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        [self.buttonNope setEnabled:YES];
//    });
}

- (void)enableButtons:(BOOL)enable {
    self.buttonLifetime.enabled = enable;
    self.button1Month.enabled = enable;
    self.button3Months.enabled = enable;
    self.buttonYearly.enabled = enable;
    self.buttonHaveLicenceCode.enabled = enable;
    self.buttonRestorePrevious.enabled = enable;
}

- (void)updateUi {
    [self update1MonthButton];
    [self update3MonthsButton];
    [self update1YearButton];
    [self updateLifeTimeButton];
    
    [self.tableView reloadData];
}

- (void)update1MonthButton {
    UpgradeManagerState state = ProUpgradeIAPManager.sharedInstance.state;
    
    NSAttributedString *attString = [self get2LineAttributedString:@"1 Month" subtitle:@"Loading..."];
    [self.button1Month setEnabled:NO];
    
    SKProduct* product = ProUpgradeIAPManager.sharedInstance.availableProducts[kMonthly];
    if(state == kReady && product) {
        NSString * priceText = [self getPriceTextFromProduct:product];
        
        attString = [self get2LineAttributedString:@"1 Month" subtitle:[NSString stringWithFormat:@"%@/month", priceText]];
        [self.button1Month setEnabled:YES];
    }
    else if(state == kCouldNotGetProducts) {
        attString = [self get2LineAttributedString:@"1 Month" subtitle:@"Momentarily Unavailable"];
    }
    
    [[self.button1Month titleLabel] setNumberOfLines:2];
    [[self.button1Month titleLabel] setLineBreakMode:NSLineBreakByWordWrapping];
    [self.button1Month setAttributedTitle:attString forState:UIControlStateNormal];
}

- (void)update3MonthsButton {
    UpgradeManagerState state = ProUpgradeIAPManager.sharedInstance.state;
    
    NSAttributedString *attString = [self get3LineAttributedString:@"3 Months" subtitle:@"Loading..." bonusText:@""];
    [self.button3Months setEnabled:NO];
    
    SKProduct* product = ProUpgradeIAPManager.sharedInstance.availableProducts[k3Monthly];
    if(state == kReady && product) {
        SKProduct* monthlyProduct = ProUpgradeIAPManager.sharedInstance.availableProducts[kMonthly];
        NSString * bonusText;
        if(monthlyProduct) {
            int percentSavings = calculatePercentageSavings(product.price, monthlyProduct.price, 3);
            bonusText = [NSString stringWithFormat:@"%@/month (Save %d%%)", [self getPriceTextFromProduct:product divisor:3], percentSavings];
        }
        else {
            bonusText = [NSString stringWithFormat:@"%@/month", [self getPriceTextFromProduct:product divisor:3]];
        }
        
        attString = [self get3LineAttributedString:@"3 Months" subtitle:[self getPriceTextFromProduct:product] bonusText:bonusText];
        [self.button3Months setEnabled:YES];
    }
    else if(state == kCouldNotGetProducts) {
        attString = [self get3LineAttributedString:@"3 Months" subtitle:@"Momentarily Unavailable" bonusText:@"Please Try Again Later"];
    }
    
    [[self.button3Months titleLabel] setNumberOfLines:3];
    [[self.button3Months titleLabel] setLineBreakMode:NSLineBreakByWordWrapping];
    [self.button3Months setAttributedTitle:attString forState:UIControlStateNormal];
}

- (void)update1YearButton {
    UpgradeManagerState state = ProUpgradeIAPManager.sharedInstance.state;
    
    NSAttributedString *attString = [self get3LineAttributedString:@"1 Year" subtitle:@"Loading..." bonusText:@""];
    [self.buttonYearly setEnabled:NO];
    
    SKProduct* product = ProUpgradeIAPManager.sharedInstance.availableProducts[kYearly];
    if(state == kReady && product) {
        SKProduct* monthlyProduct = ProUpgradeIAPManager.sharedInstance.availableProducts[kMonthly];
        NSString * bonusText;
        if(monthlyProduct) {
            int percentSavings = calculatePercentageSavings(product.price, monthlyProduct.price, 12);
            bonusText = [NSString stringWithFormat:@"%@/month (Save %d%%)", [self getPriceTextFromProduct:product divisor:12], percentSavings];
        }
        else {
            bonusText = [NSString stringWithFormat:@"%@/month", [self getPriceTextFromProduct:product divisor:12]];
        }
        
        attString = [self get3LineAttributedString:@"1 Year" subtitle:[self getPriceTextFromProduct:product] bonusText:bonusText];
        [self.buttonYearly setEnabled:YES];
    }
    else if(state == kCouldNotGetProducts) {
        attString = [self get3LineAttributedString:@"1 Year" subtitle:@"Momentarily Unavailable" bonusText:@"Please Try Again Later"];
    }
    
    [[self.buttonYearly titleLabel] setNumberOfLines:3];
    [[self.buttonYearly titleLabel] setLineBreakMode:NSLineBreakByWordWrapping];
    [self.buttonYearly setAttributedTitle:attString forState:UIControlStateNormal];
}

- (void)updateLifeTimeButton {
    UpgradeManagerState state = ProUpgradeIAPManager.sharedInstance.state;

    NSAttributedString *attString = [self get3LineAttributedString:@"Lifetime" subtitle:@"Loading..." bonusText:@""];
    [self.buttonLifetime setEnabled:NO];

    SKProduct* product = ProUpgradeIAPManager.sharedInstance.availableProducts[kIapProId];
    if(state == kReady && product) {
        NSString * priceText = [self getPriceTextFromProduct:product];

        attString = [self get3LineAttributedString:@"Lifetime" subtitle:priceText bonusText:@"(No Subscription)"];
        [self.buttonLifetime setEnabled:YES];
    }
    else if(state == kCouldNotGetProducts) {
        attString = [self get3LineAttributedString:@"Lifetime" subtitle:@"Momentarily Unavailable" bonusText:@"Please Try Again Later"];
    }
    
    [[self.buttonLifetime titleLabel] setNumberOfLines:3];
    [[self.buttonLifetime titleLabel] setLineBreakMode:NSLineBreakByWordWrapping];
    [self.buttonLifetime setAttributedTitle:attString forState:UIControlStateNormal];
}

- (NSAttributedString*)get2LineAttributedString:(NSString*)title subtitle:(NSString*)subtitle {
    NSMutableAttributedString *attString = [[NSMutableAttributedString alloc] init];
    
    [attString appendAttributedString:[[NSAttributedString alloc] initWithString:title attributes:self.titleAttributes]];
    [attString appendAttributedString:[[NSAttributedString alloc] initWithString:@"\n"]];
    
    [attString appendAttributedString:[[NSAttributedString alloc] initWithString:subtitle attributes:self.subtitleAttributes]];

    return [attString copy];
}

- (NSAttributedString*)get3LineAttributedString:(NSString*)title subtitle:(NSString*)subtitle bonusText:(NSString*)bonusText {
    NSMutableAttributedString *attString = [[NSMutableAttributedString alloc] init];

    [attString appendAttributedString:[[NSAttributedString alloc] initWithString:title attributes:self.titleAttributes]];
    [attString appendAttributedString:[[NSAttributedString alloc] initWithString:@"\n"]];
     
    [attString appendAttributedString:[[NSAttributedString alloc] initWithString:subtitle attributes:self.subtitleAttributes]];
    [attString appendAttributedString:[[NSAttributedString alloc] initWithString:@"\n"]];
     
    [attString appendAttributedString:[[NSAttributedString alloc] initWithString:bonusText attributes:self.bonusTextAttributes]];
    
    return [attString copy];
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    if(indexPath.row == 3 && ProUpgradeIAPManager.sharedInstance.availableProducts[kMonthly] == nil) {
        return 0;
    }
    if(indexPath.row == 4 && ProUpgradeIAPManager.sharedInstance.availableProducts[k3Monthly] == nil) {
        return 0;
    }
    if(indexPath.row == 5 && ProUpgradeIAPManager.sharedInstance.availableProducts[kYearly] == nil) {
        return 0;
    }

    return [super tableView:tableView heightForRowAtIndexPath:indexPath];
}

- (NSDictionary*)getAttributedTextDictionaryWithFontSize:(CGFloat)fontSize foregroundColor:(UIColor*)foregroundColor {
    return [self getAttributedTextDictionaryWithFontSize:fontSize foregroundColor:foregroundColor bold:YES];
}

- (NSDictionary*)getAttributedTextDictionaryWithFontSize:(CGFloat)fontSize foregroundColor:(UIColor*)foregroundColor bold:(BOOL)bold {
    NSMutableParagraphStyle *style = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
    [style setParagraphSpacing:10.0f];
    [style setAlignment:NSTextAlignmentCenter];
    [style setLineBreakMode:NSLineBreakByWordWrapping];
    
    UIFont *font = [UIFont fontWithName:(bold ? kFontName : kFontNameNoneBold) size:fontSize];
    
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

- (NSString *)getPriceTextFromProduct:(SKProduct*)product {
    return [self getPriceTextFromProduct:product divisor:1];
}

- (NSString *)getPriceTextFromProduct:(SKProduct*)product divisor:(int)divisor {
    NSNumberFormatter* formatter = [[NSNumberFormatter alloc] init];
    formatter.numberStyle = NSNumberFormatterCurrencyStyle;
    formatter.locale = product.priceLocale;
    
    NSDecimalNumber* div = [NSDecimalNumber decimalNumberWithMantissa:divisor exponent:0 isNegative:NO];
    NSDecimalNumber* price = [product.price decimalNumberByDividingBy:div];
    
    NSString* localCurrency = [formatter stringFromNumber:price];
    NSString* priceText = [NSString stringWithFormat:@"%@", localCurrency];
    return priceText;
}

int calculatePercentageSavings(NSDecimalNumber* price, NSDecimalNumber* monthlyPrice, int numberOfMonths) {
    NSDecimalNumber* div = [NSDecimalNumber decimalNumberWithMantissa:numberOfMonths exponent:0 isNegative:NO];
    NSDecimalNumber* monthlyCalculatedPrice = [price decimalNumberByDividingBy:div];

    NSDecimalNumber *oneHundred = [NSDecimalNumber decimalNumberWithMantissa:100 exponent:0 isNegative:NO];
    NSDecimalNumber *num = [[monthlyPrice decimalNumberBySubtracting:monthlyCalculatedPrice] decimalNumberByMultiplyingBy:oneHundred];
    
    return [[num decimalNumberByDividingBy:monthlyPrice] intValue];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (IBAction)on1Month:(id)sender {
    [self purchase:kMonthly];
}

- (IBAction)on3Months:(id)sender {
    [self purchase:k3Monthly];
}

- (IBAction)on1Year:(id)sender {
    [self purchase:kYearly];
}

- (IBAction)onLifetime:(id)sender {
    [self purchase:kIapProId];
}

- (void)purchase:(NSString*)productId {
    if(ProUpgradeIAPManager.sharedInstance.state != kReady || ProUpgradeIAPManager.sharedInstance.availableProducts[productId] == nil) {
        [Alerts warn:self
               title:@"Product Error"
             message:@"Could not access Upgrade Products on App Store. Please try again later."];
    }
    else {
        [SVProgressHUD showWithStatus:@"Purchasing..."];
        [self enableButtons:NO];

        [ProUpgradeIAPManager.sharedInstance purchase:productId completion:^(NSError * _Nullable error) {
            [SVProgressHUD dismiss];
            [self enableButtons:YES];

            if (error == nil) {
                // Pro is ready to go...
                
                dispatch_async(dispatch_get_main_queue(), ^(void) {
                    [self.navigationController popToRootViewControllerAnimated:YES];
                });
            }
            else{
                [Alerts error:self title:@"Problem Purchasing" error:error];
            }
        }];
    }
}

- (IBAction)onRestorePrevious:(id)sender {
    [self enableButtons:NO];
    [SVProgressHUD showWithStatus:@"Restoring..."];
    
    [ProUpgradeIAPManager.sharedInstance restorePrevious:^(NSError * _Nonnull error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self enableButtons:YES];
            [SVProgressHUD dismiss];
            
            if(error) {
                [Alerts error:self title:@"Issue Restoring Purchase" error:error];
            }
            else {
                if(!Settings.sharedInstance.isPro) {
                    [Alerts info:self title:@"Restoration Unsuccessful" message:@"Upgrade could not be restored from previous purchase. Are you sure you have purchased this item?" completion:nil];
                }
                else {
                    dispatch_async(dispatch_get_main_queue(), ^(void) {
                        [self.navigationController popToRootViewControllerAnimated:YES];
                    });
                }
            }
        });
    }];
}

- (IBAction)onNoThanks:(id)sender {
    [SVProgressHUD dismiss];
    [self.navigationController popToRootViewControllerAnimated:YES];
}
//
//- (IBAction)onHaveLicenceCode:(id)sender {
//    [Alerts OkCancelWithTextField:self textFieldPlaceHolder:@"Licence Code" title:@"Licence Code" message:@"Please Enter Your Licence Code" completion:^(NSString *text, BOOL response) {
//        if(response) {
//            [self enableButtons:NO];
//            [SVProgressHUD showWithStatus:@"Verifying Licence..."];
//
//            [LicenceCodeManager.sharedInstance verifyCode:text completion:^(BOOL success, NSError * _Nullable error) {
//                dispatch_async(dispatch_get_main_queue(), ^(void) {
//                    [self enableButtons:YES];
//                    [SVProgressHUD dismiss];
//
//                    if(success) {
//                        // Set Pro...
//
//                        [self.navigationController popToRootViewControllerAnimated:YES];
//                    }
//                    else {
//                        [Alerts error:self title:@"Licence Code Error" error:error];
//                    }});
//            }];
//        }
//    }];
// }

@end
