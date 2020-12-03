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
#import "Model.h"
#import "SharedAppAndAutoFillSettings.h"

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

@property (weak, nonatomic) IBOutlet UIView *viewFreeTrialInfo;
@property (weak, nonatomic) IBOutlet UIView *buttonStartFreeTrial;
@property (weak, nonatomic) IBOutlet UILabel *buttonStartFreeTrialTitle;
@property (weak, nonatomic) IBOutlet UILabel *buttonStartFreeTrialSubtitle;
@property (weak, nonatomic) IBOutlet UILabel *buttonStartFreeTrialSubSubTitle;
@property (weak, nonatomic) IBOutlet UITextView *termsAndConditionsTextView;

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
    
    [ProUpgradeIAPManager.sharedInstance initialize]; 
}

- (void)setupUi {
    const CGFloat kRadius = 10.0f;
    
    self.buttonViewMonthly.layer.cornerRadius = kRadius;
    self.buttonViewYearly.layer.cornerRadius = kRadius;
    self.buttonViewLifeTime.layer.cornerRadius = kRadius;
    self.buttonViewFamilySharing.layer.cornerRadius = kRadius;
    self.buttonStartFreeTrial.layer.cornerRadius = kRadius;
    
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

    UITapGestureRecognizer *trial = [[UITapGestureRecognizer alloc] initWithTarget:self
                                                                            action:@selector(onStartFreeTrial)];
    [self.buttonStartFreeTrial addGestureRecognizer:trial];

    

    [self bindDeveloperMessage];

    [self bindFreeTrialInfo];
    
    
    
    static NSString* const kTextViewInterfaceBuilderId = @"k2u-lE-LrX.text";
    NSString *tc = NSLocalizedStringFromTable(kTextViewInterfaceBuilderId, @"Upgrade", @"");
    if (tc && ![tc isEqualToString:kTextViewInterfaceBuilderId]) {
        self.termsAndConditionsTextView.text = tc;
    }
}

- (void)bindFreeTrialInfo {
    if ([SharedAppAndAutoFillSettings.sharedInstance isPro]) {
        self.buttonStartFreeTrial.hidden = YES;
        self.viewFreeTrialInfo.hidden = YES;
    }
    else if (SharedAppAndAutoFillSettings.sharedInstance.freeTrialEnd) {
        self.buttonStartFreeTrial.hidden = YES;
        self.viewFreeTrialInfo.hidden = NO;
        
        NSInteger daysRemaining = SharedAppAndAutoFillSettings.sharedInstance.freeTrialDaysLeft;

        if (SharedAppAndAutoFillSettings.sharedInstance.isFreeTrial) {
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
        
        NSString* loc = NSLocalizedString(@"generic_biometric_unlock_fmt", @"%@ Unlock");
        NSString* biometricUnlockFeature = [NSString stringWithFormat:loc, [BiometricsManager.sharedInstance getBiometricIdName]];

        NSString* loc2 = NSLocalizedString(@"upgrade_vc_enjoy_features_by_upgrading_fmt", @"Enjoy %@ and other Pro features by Upgrading!");
        NSString* localized = [NSString stringWithFormat:loc2, biometricUnlockFeature];

        self.upgradeForFeaturesSubLabel.text = localized;
    }
    else {
        self.buttonStartFreeTrial.hidden = NO;
        self.viewFreeTrialInfo.hidden = YES;
        
        NSString* loc = NSLocalizedString(@"upgrade_vc_start_your_free_trial", @"90 Day Trial");
        NSString* loc2 = NSLocalizedString(@"upgrade_vc_start_your_free_trial_price_free", @"Free");
        NSString* loc3 = NSLocalizedString(@"upgrade_vc_start_your_free_trial_subtitle", @"No subscription or commitment required!");

        self.buttonStartFreeTrialTitle.text = loc;
        self.buttonStartFreeTrialSubtitle.text = loc2;
        self.buttonStartFreeTrialSubSubTitle.text = loc3;
    }
}

- (void)bindDeveloperMessage {
    NSString* loc = NSLocalizedString(@"generic_biometric_unlock_fmt", @"%@ Unlock");
    NSString* biometricUnlockFeature = [NSString stringWithFormat:loc, [BiometricsManager.sharedInstance getBiometricIdName]];
    NSString* str = NSLocalizedString(@"upgrade_short_developer_message_fmt", @"");
    self.developerMessage.text = [NSString stringWithFormat:str, biometricUnlockFeature];
}

- (void)onProStatusChanged:(id)param {
    dispatch_async(dispatch_get_main_queue(), ^(void) {
        [self bindUi];
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
    
    SKProduct* product = ProUpgradeIAPManager.sharedInstance.monthlyProduct;
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
    
    SKProduct* product = ProUpgradeIAPManager.sharedInstance.yearlyProduct;
    if(state == kReady && product) {
        SKProduct* monthlyProduct = ProUpgradeIAPManager.sharedInstance.monthlyProduct;
        
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
    
    SKProduct* product = ProUpgradeIAPManager.sharedInstance.lifeTimeProduct;
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
    [self purchase:ProUpgradeIAPManager.sharedInstance.monthlyProduct];
}

- (void)onYearly {
    [self purchase:ProUpgradeIAPManager.sharedInstance.yearlyProduct];
}

- (void)onLifeTime {
    [self purchase:ProUpgradeIAPManager.sharedInstance.lifeTimeProduct];
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
    
    BOOL optedInToFreeTrial = SharedAppAndAutoFillSettings.sharedInstance.hasOptedInToFreeTrial;
    
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
                BOOL freeTrialStarted = SharedAppAndAutoFillSettings.sharedInstance.hasOptedInToFreeTrial != optedInToFreeTrial;
                
                if(!SharedAppAndAutoFillSettings.sharedInstance.isPro && !freeTrialStarted) {
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

- (void)purchase:(SKProduct*)product {
    if(ProUpgradeIAPManager.sharedInstance.state != kReady || product == nil) {
        [Alerts warn:self
               title:NSLocalizedString(@"upgrade_vc_product_error_title", @"Product Error")
             message:NSLocalizedString(@"upgrade_vc_product_error_message", @"Could not access Upgrade Products on App Store. Please try again later.")];
    }
    else {
        [SVProgressHUD showWithStatus:NSLocalizedString(@"upgrade_vc_progress_purchasing", @"Purchasing...")];
        [self enableButtons:NO];

        [ProUpgradeIAPManager.sharedInstance purchaseAndCheckReceipts:product completion:^(NSError * _Nullable error) {
            [self enableButtons:YES];
            [SVProgressHUD dismiss];

            if (error == nil) {
                
                
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
    self.buttonStartFreeTrial.userInteractionEnabled = enable;
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

- (void)onStartFreeTrial {
    [SVProgressHUD showWithStatus:NSLocalizedString(@"generic_loading", @"Loading...")];
    [self enableButtons:NO];
    
    [ProUpgradeIAPManager.sharedInstance startFreeTrial:^(NSError * _Nullable error) {
        [self enableButtons:YES];
        [SVProgressHUD dismiss];

        if (!error) {
            [self dismiss];
        }
        else {
            [Alerts error:self title:@"Could not start Free Trial" error:error completion:nil];
        }
    }];
}

@end

