//
//  WelcomeFreemiumViewController.m
//  Strongbox
//
//  Created by Mark on 03/04/2020.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import "FreeTrialOnboardingViewController.h"
#import "BiometricsManager.h"
#import "ProUpgradeIAPManager.h"
#import "Alerts.h"
#import "SVProgressHUD.h"
#import "Model.h"
#import "AppPreferences.h"
#import "UpgradeViewController.h"
#import "Utils.h"

@interface FreeTrialOnboardingViewController ()

@property (weak, nonatomic) IBOutlet UIButton *buttonTryPro;
@property (weak, nonatomic) IBOutlet UILabel *labelBiometricUnlockFeature;

@property (weak, nonatomic) IBOutlet UIImageView *imageViewOK1;
@property (weak, nonatomic) IBOutlet UIImageView *imageViewOK2;
@property (weak, nonatomic) IBOutlet UIImageView *imageViewOK3;
@property (weak, nonatomic) IBOutlet UIImageView *imageViewOK4;

@property (weak, nonatomic) IBOutlet UILabel *labelPrice;
@property (weak, nonatomic) IBOutlet UIStackView *yubiKeyFeature;

@property SKProduct* yearly;

@end

@implementation FreeTrialOnboardingViewController

- (BOOL)shouldAutorotate {
    return UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad;
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad ? UIInterfaceOrientationMaskAll : UIInterfaceOrientationMaskPortrait;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    self.yearly = ProUpgradeIAPManager.sharedInstance.yearlyProduct;

    [self setupUi];
}

- (void)setupUi {
    self.buttonTryPro.layer.cornerRadius = 5.0f;
    
    
    
    self.imageViewOK1.image = [UIImage imageNamed:@"ok"];
    self.imageViewOK2.image = [UIImage imageNamed:@"ok"];
    self.imageViewOK3.image = [UIImage imageNamed:@"ok"];
    self.imageViewOK4.image = [UIImage imageNamed:@"ok"];

    NSString* loc = NSLocalizedString(@"generic_biometric_unlock_fmt", @"%@ Unlock");
    NSString* fmt = [NSString stringWithFormat:loc, [BiometricsManager.sharedInstance getBiometricIdName]];
    self.labelBiometricUnlockFeature.text = fmt;
    
    NSString* priceText = [self getPriceTextFromProduct:self.yearly];
    
    NSString* priceFmt = NSLocalizedString(@"price_per_year_after_free_trial_fmt", "Then %@ every year");
    
    self.labelPrice.text = [NSString stringWithFormat:priceFmt, priceText];
    
    self.yubiKeyFeature.hidden = Utils.isiPadPro;
}

- (NSString *)getPriceTextFromProduct:(SKProduct*)product {
    return [self getPriceTextFromProduct:product divisor:1];
}

- (NSString *)getPriceTextFromProduct:(SKProduct*)product divisor:(int)divisor {
    NSNumberFormatter* formatter = [[NSNumberFormatter alloc] init];
    formatter.numberStyle = NSNumberFormatterCurrencyStyle;
    formatter.locale = product.priceLocale;
    
    NSDecimalNumber* div = [NSDecimalNumber decimalNumberWithMantissa:divisor exponent:0 isNegative:NO];
    NSDecimalNumber* price = [[self getEffectivePrice:product] decimalNumberByDividingBy:div];
    
    NSString* localCurrency = [formatter stringFromNumber:price];
    NSString* priceText = [NSString stringWithFormat:@"%@", localCurrency];
    return priceText;
}

- (NSDecimalNumber*)getEffectivePrice:(SKProduct*)product {
    if(product.introductoryPrice) {
        if ( [product.introductoryPrice.price isEqual:NSDecimalNumber.zero] ) {
            
            return product.price;
        }
        else {
            return product.introductoryPrice.price;
        }
    }
    
    return product.price;
}

- (IBAction)onAskMeLater:(id)sender {
    [self onDismiss];
}

- (void)onDismiss {
    __weak FreeTrialOnboardingViewController* weakSelf = self;

    dispatch_async(dispatch_get_main_queue(), ^{
        if ( weakSelf.onDone ) {
            weakSelf.onDone(NO, NO);
            weakSelf.onDone = nil; 
        }
    });
}

- (IBAction)onTryPro:(id)sender {
    [ProUpgradeIAPManager.sharedInstance purchaseAndCheckReceipts:self.yearly
                                                       completion:^(NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if ( error ) {
                if ( error.code != SKErrorPaymentCancelled ) {
                    [Alerts error:self error:error];
                }
            }
            else {
                [self onDismiss];
            }
        });
    }];
}

- (IBAction)onLearnMore:(id)sender {
    UIStoryboard* storyboard = [UIStoryboard storyboardWithName:@"Upgrade" bundle:nil];
    UpgradeViewController* vc = [storyboard instantiateInitialViewController];

    vc.onDone = ^{
        dispatch_async(dispatch_get_main_queue(), ^{
            [self onDismiss];
        });
    };
    
    [self presentViewController:vc animated:YES completion:nil];
}

@end
