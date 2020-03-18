//
//  UpgradeViewController.m
//  Strongbox-iOS
//
//  Created by Mark on 11/03/2020.
//  Copyright © 2020 Mark McGuill. All rights reserved.
//

#import "UpgradeViewController.h"
#import "SVProgressHUD.h"
#import "ProUpgradeIAPManager.h"
#import "Settings.h"
#import "Alerts.h"
#import "BiometricsManager.h"

@interface UpgradeViewController () <SKStoreProductViewControllerDelegate>

@property (weak, nonatomic) IBOutlet UIView *buttonViewMonthly;
@property (weak, nonatomic) IBOutlet UIView *buttonViewYearly;
@property (weak, nonatomic) IBOutlet UIView *buttonViewLifeTime;
@property (weak, nonatomic) IBOutlet UIView *buttonViewFamilySharing;
@property (weak, nonatomic) IBOutlet UIButton *buttonRestorePrevious;

@property (weak, nonatomic) IBOutlet UILabel *buttonMonthlyTitle;
@property (weak, nonatomic) IBOutlet UILabel *buttonYearlyTitle;
@property (weak, nonatomic) IBOutlet UILabel *buttonLifeTimeTitle;
@property (weak, nonatomic) IBOutlet UILabel *buttonFamilySharingTitle;
@property (weak, nonatomic) IBOutlet UILabel *buttonFamilySharingSubtitle;

@property (weak, nonatomic) IBOutlet UILabel *monthlyPrice;
@property (weak, nonatomic) IBOutlet UILabel *yearlyBonusLabel;
@property (weak, nonatomic) IBOutlet UILabel *yearlyPrice;
@property (weak, nonatomic) IBOutlet UILabel *lifeTimePrice;
@property (weak, nonatomic) IBOutlet UILabel *lifeTimeBonusLabel;

@property (weak, nonatomic) IBOutlet UILabel *developerMessage;
@property (weak, nonatomic) IBOutlet UILabel *freeTrialExpiryIndicator;
@property (weak, nonatomic) IBOutlet UILabel *upgradeForFeaturesSubLabel;

@end

const static NSUInteger kFamilySharingProductId = 1481853033;

@implementation UpgradeViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    [self setupUi];
    
    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(onProStatusChanged:)
                                               name:kProStatusChangedNotificationKey
                                             object:nil];
    
    [self bindUi];
    
    ProUpgradeIAPManager.sharedInstance.productsAvailableNotify = ^{
        dispatch_async(dispatch_get_main_queue(), ^(void) {
            [self bindUi];
        });
    };
    
    [ProUpgradeIAPManager.sharedInstance initialize]; // Not sure if we need to do this?
    
}

- (void)setupUi {
    const CGFloat kRadius = 10.0f;
    
    self.buttonViewMonthly.layer.cornerRadius = kRadius;
    self.buttonViewYearly.layer.cornerRadius = kRadius;
    self.buttonViewLifeTime.layer.cornerRadius = kRadius;
    self.buttonViewFamilySharing.layer.cornerRadius = kRadius;
    
    UITapGestureRecognizer *m = [[UITapGestureRecognizer alloc] initWithTarget:self
                                                                        action:@selector(onMonthly)];
    [self.buttonViewMonthly addGestureRecognizer:m];

    UITapGestureRecognizer *y = [[UITapGestureRecognizer alloc] initWithTarget:self
                                                                        action:@selector(onYearly)];
    [self.buttonViewYearly addGestureRecognizer:y];

    UITapGestureRecognizer *l = [[UITapGestureRecognizer alloc] initWithTarget:self
                                                                        action:@selector(onLifeTime)];
    [self.buttonViewLifeTime addGestureRecognizer:l];

    UITapGestureRecognizer *f = [[UITapGestureRecognizer alloc] initWithTarget:self
                                                                        action:@selector(onFamilySharing)];
    [self.buttonViewFamilySharing addGestureRecognizer:f];

    // Developer Message...

    [self bindDeveloperMessage];

    [self bindFreeTrialInfo];

    [self bindUpgradeForFeaturesSubLabel];
}

- (void)bindUpgradeForFeaturesSubLabel {
    NSString* loc = NSLocalizedString(@"db_management_biometric_unlock_fmt", @"%@ Unlock");
    NSString* biometricUnlockFeature = [NSString stringWithFormat:loc, [BiometricsManager.sharedInstance getBiometricIdName]];

    NSString* loc2 = NSLocalizedString(@"upgrade_vc_enjoy_features_by_upgrading_fmt", @"Enjoy %@ and other Pro features by Upgrading!");
    NSString* localized = [NSString stringWithFormat:loc2, biometricUnlockFeature];

    self.upgradeForFeaturesSubLabel.text = localized;
}

- (void)bindFreeTrialInfo {
    NSInteger daysRemaining = [Settings.sharedInstance getFreeTrialDaysRemaining];
    
    if (Settings.sharedInstance.isFreeTrial) {
        NSString* loc = NSLocalizedString(@"upgrade_vc_you_have_n_days_remaining_fmt", @"You have %ld days left in your Pro trial");
        self.freeTrialExpiryIndicator.text = [NSString stringWithFormat:loc, daysRemaining];
    }
    else {
        NSString* loc = NSLocalizedString(@"upgrade_vc_your_free_trial_expired", @"Your free trial of Strongbox Pro has expired.");
        self.freeTrialExpiryIndicator.text = loc;
    }

    if (daysRemaining < 28) {
        if (daysRemaining < 14) {
            self.freeTrialExpiryIndicator.textColor = UIColor.systemRedColor;
        }
        else {
            self.freeTrialExpiryIndicator.textColor = UIColor.systemOrangeColor;
        }
    }
}

- (void)bindDeveloperMessage {
    NSString* loc = NSLocalizedString(@"db_management_biometric_unlock_fmt", @"%@ Unlock");
    NSString* biometricUnlockFeature = [NSString stringWithFormat:loc, [BiometricsManager.sharedInstance getBiometricIdName]];
    NSString* str = NSLocalizedString(@"upgrade_short_developer_message_fmt", @"");
    self.developerMessage.text = [NSString stringWithFormat:str, biometricUnlockFeature];
}

- (void)onProStatusChanged:(id)param {
    dispatch_async(dispatch_get_main_queue(), ^(void) {
        [self dismiss];
    });
}

- (void)bindUi {
    [self bindMonthlyPricing];
    [self bindYearlyPricing];
    [self bindLifeTimePricing];
    [self bindFamilySharing];
}

- (void)bindMonthlyPricing {
    UpgradeManagerState state = ProUpgradeIAPManager.sharedInstance.state;
        
    self.buttonMonthlyTitle.text = NSLocalizedString(@"upgrade_vc_monthly_subscription_title", @"Monthly");
    self.monthlyPrice.text = NSLocalizedString(@"generic_loading", @"Loading...");
    self.buttonViewMonthly.userInteractionEnabled = NO;
    
    SKProduct* product = ProUpgradeIAPManager.sharedInstance.availableProducts[kMonthly];
    if(state == kReady && product) {
        NSString * priceText = [self getPriceTextFromProduct:product];
        NSString* fmt = [NSString stringWithFormat:NSLocalizedString(@"upgrade_vc_price_per_month_fmt", @"%@ / month"), priceText];
        
        self.monthlyPrice.text = fmt;
        self.buttonViewMonthly.userInteractionEnabled = YES;
    }
    else if(state == kCouldNotGetProducts) {
        self.monthlyPrice.text = NSLocalizedString(@"upgrade_vc_price_not_currently_available", @"Unavailable... Check your network connection");
    }
}

- (void)bindYearlyPricing {
    UpgradeManagerState state = ProUpgradeIAPManager.sharedInstance.state;

    self.buttonYearlyTitle.text = NSLocalizedString(@"upgrade_vc_yearly_subscription_title", @"Monthly");
    self.yearlyPrice.text = NSLocalizedString(@"generic_loading", @"Loading...");
    self.yearlyBonusLabel.text = @"";
    self.buttonViewYearly.userInteractionEnabled = NO;
    
    SKProduct* product = ProUpgradeIAPManager.sharedInstance.availableProducts[kYearly];
    if(state == kReady && product) {
        SKProduct* monthlyProduct = ProUpgradeIAPManager.sharedInstance.availableProducts[kMonthly];
        
        NSString * bonusText;
        if(monthlyProduct) {
            int percentSavings = calculatePercentageSavings([self getEffectivePrice:product], [self getEffectivePrice:monthlyProduct], 12);
            bonusText = [NSString stringWithFormat:NSLocalizedString(@"upgrade_vc_price_per_month_with_percentage_saving_fmt", @"%@ / month (Save %d%%)"), [self getPriceTextFromProduct:product divisor:12], percentSavings];
        }
        else {
            bonusText = [NSString stringWithFormat:NSLocalizedString(@"upgrade_vc_price_per_month_fmt", @"%@ / month"), [self getPriceTextFromProduct:product divisor:12]];
        }
        
        self.yearlyPrice.text = [self getPriceTextFromProduct:product];
        self.yearlyBonusLabel.text = bonusText;
        
        self.buttonViewYearly.userInteractionEnabled = YES;
    }
    else if(state == kCouldNotGetProducts) {
        self.yearlyPrice.text = NSLocalizedString(@"upgrade_vc_price_not_currently_available", @"Unavailable... Check your network connection");
    }
}

- (void)bindLifeTimePricing {
    UpgradeManagerState state = ProUpgradeIAPManager.sharedInstance.state;

    self.buttonLifeTimeTitle.text = NSLocalizedString(@"upgrade_vc_lifetime_purchase_title", @"Lifetime");
    self.lifeTimePrice.text = NSLocalizedString(@"generic_loading", @"Loading...");
    self.buttonViewLifeTime.userInteractionEnabled = NO;
    self.lifeTimeBonusLabel.text = @"";
    
    SKProduct* product = ProUpgradeIAPManager.sharedInstance.availableProducts[kIapProId];
    if(state == kReady && product) {
        NSString * priceText = [self getPriceTextFromProduct:product];
        self.lifeTimePrice.text = priceText;
        self.lifeTimeBonusLabel.text = NSLocalizedString(@"upgrade_vc_lifetime_subtitle_no_sub", @"(No Subscription)");
        self.buttonViewLifeTime.userInteractionEnabled = YES;
    }
    else if(state == kCouldNotGetProducts) {
        self.lifeTimePrice.text = NSLocalizedString(@"upgrade_vc_price_not_currently_available", @"Unavailable... Check your network connection");
    }
}

- (void)bindFamilySharing {
    self.buttonFamilySharingTitle.text = NSLocalizedString(@"upgrade_family_sharing_button_title", @"Need Family Sharing?");
    self.buttonFamilySharingSubtitle.text = NSLocalizedString(@"upgrade_family_sharing_button_subtitle", @"Tap for more info...");
}

- (IBAction)onFreeProComparisonChart:(id)sender {
    [self performSegueWithIdentifier:@"segueToFreeProComparison" sender:nil];
}

- (IBAction)onNoThanks:(id)sender {
    [self dismiss];
}

- (void)dismiss {
    [SVProgressHUD dismiss];
    [self.presentingViewController dismissViewControllerAnimated:YES completion:nil];
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
    if (@available(iOS 11.2, *)) {
        if(product.introductoryPrice) {
            return product.introductoryPrice.price;
        }
    }

    return product.price;
}

static int calculatePercentageSavings(NSDecimalNumber* price, NSDecimalNumber* monthlyPrice, int numberOfMonths) {
    NSDecimalNumber* div = [NSDecimalNumber decimalNumberWithMantissa:numberOfMonths exponent:0 isNegative:NO];
    NSDecimalNumber* monthlyCalculatedPrice = [price decimalNumberByDividingBy:div];

    NSDecimalNumber *oneHundred = [NSDecimalNumber decimalNumberWithMantissa:100 exponent:0 isNegative:NO];
    NSDecimalNumber *num = [[monthlyPrice decimalNumberBySubtracting:monthlyCalculatedPrice] decimalNumberByMultiplyingBy:oneHundred];
    
    return [[num decimalNumberByDividingBy:monthlyPrice] intValue];
}

- (void)onMonthly {
    NSLog(@"Monthly");
    [self purchase:kMonthly];
}

- (void)onYearly {
    NSLog(@"onYearly");
    [self purchase:kYearly];
}

- (void)onLifeTime {
    NSLog(@"onLifeTime");
    [self purchase:kIapProId];
}

- (void)onFamilySharing {
    NSLog(@"onFamilySharing");
    
    self.buttonViewFamilySharing.userInteractionEnabled = NO;

    [Alerts okCancel:self
               title:NSLocalizedString(@"upgrade_family_sharing_info_title", @"Title of info dialog about Family Sharing upgrade")
             message:NSLocalizedString(@"upgrade_family_sharing_info_message", @"A message about how you will need to download/purchase a separate App for Family Sharing to work")
              action:^(BOOL response) {
        if(response) {
            [self showFamilySharingAppInAppStore];
        }
    }];
}

- (IBAction)onIHaveQuestions:(id)sender {
    [self performSegueWithIdentifier:@"segueToQuestions" sender:nil];
}

- (IBAction)onRestorePurchase:(id)sender {
    [self enableButtons:NO];
    [SVProgressHUD showWithStatus:NSLocalizedString(@"upgrade_vc_progress_restoring", @"Restoring...")];
    
    [ProUpgradeIAPManager.sharedInstance restorePrevious:^(NSError * _Nonnull error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self enableButtons:YES];
            [SVProgressHUD dismiss];
            
            if(error) {
                [Alerts error:self
                        title:NSLocalizedString(@"upgrade_vc_problem_restoring", @"Issue Restoring Purchase")
                        error:error];
            }
            else {
                if(!Settings.sharedInstance.isPro) {
                    [Alerts info:self
                           title:NSLocalizedString(@"upgrade_vc_restore_unsuccessful_title", @"Restoration Unsuccessful")
                         message:NSLocalizedString(@"upgrade_vc_restore_unsuccessful_message", @"Upgrade could not be restored from previous purchase. Are you sure you have purchased this item?")
                      completion:nil];
                }
                else {
                    dispatch_async(dispatch_get_main_queue(), ^(void) {
                        [self dismiss];
                    });
                }
            }
        });
    }];
}

- (void)purchase:(NSString*)productId {
    if(ProUpgradeIAPManager.sharedInstance.state != kReady || ProUpgradeIAPManager.sharedInstance.availableProducts[productId] == nil) {
        [Alerts warn:self
               title:NSLocalizedString(@"upgrade_vc_product_error_title", @"Product Error")
             message:NSLocalizedString(@"upgrade_vc_product_error_message", @"Could not access Upgrade Products on App Store. Please try again later.")];
    }
    else {
        [SVProgressHUD showWithStatus:NSLocalizedString(@"upgrade_vc_progress_purchasing", @"Purchasing...")];
        [self enableButtons:NO];

        [ProUpgradeIAPManager.sharedInstance purchase:productId completion:^(NSError * _Nullable error) {
            [self enableButtons:YES];
            [SVProgressHUD dismiss];

            if (error == nil) {
                // Pro is ready to go...
                
                dispatch_async(dispatch_get_main_queue(), ^(void) {
                    [self dismiss];
                });
            }
            else{
                [Alerts error:self
                        title:NSLocalizedString(@"upgrade_vc_error_purchasing", @"Problem Purchasing")
                        error:error];
            }
        }];
    }
}

- (void)enableButtons:(BOOL)enable {
    self.buttonViewMonthly.userInteractionEnabled = enable;
    self.buttonViewYearly.userInteractionEnabled = enable;
    self.buttonViewLifeTime.userInteractionEnabled = enable;
    self.buttonViewFamilySharing.userInteractionEnabled = enable;
    self.buttonRestorePrevious.enabled = enable;
}

- (void)showFamilySharingAppInAppStore {
    [SVProgressHUD showWithStatus:NSLocalizedString(@"generic_loading", @"")];
    
    SKStoreProductViewController* vc = [[SKStoreProductViewController alloc] init];
    vc.delegate = self;
    
    [vc loadProductWithParameters:@{ SKStoreProductParameterITunesItemIdentifier : @(kFamilySharingProductId) }
                  completionBlock:^(BOOL result, NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            self.buttonViewFamilySharing.userInteractionEnabled = YES;
            [SVProgressHUD dismiss];
            
            if(result) {
                [self presentViewController:vc animated:YES completion:nil];
            }
            else {
                [Alerts error:self title:NSLocalizedString(@"generic_error", @"") error:error];
            }});
    }];
}

- (void)productViewControllerDidFinish:(SKStoreProductViewController *)viewController {
    [viewController dismissViewControllerAnimated:YES completion:nil];
}

@end

