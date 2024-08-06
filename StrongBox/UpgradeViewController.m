//
//  UpgradeViewController.m
//  Strongbox-iOS
//
//  Created by Mark on 11/03/2020.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import "UpgradeViewController.h"
#import "SVProgressHUD.h"
#import "ProUpgradeIAPManager.h"
#import "Alerts.h"
#import "BiometricsManager.h"
#import "Model.h"
#import "AppPreferences.h"
#import "SaleScheduleManager.h"
#import "Utils.h"
#import "NSDate+Extensions.h"
#import "Strongbox-Swift.h"

@interface UpgradeViewController () <UIAdaptivePresentationControllerDelegate>

@property (weak, nonatomic) IBOutlet UIView *buttonViewMonthly;
@property (weak, nonatomic) IBOutlet UIView *buttonViewYearly;
@property (weak, nonatomic) IBOutlet UILabel *buttonMonthlyTitle;
@property (weak, nonatomic) IBOutlet UILabel *buttonYearlyTitle;
@property (weak, nonatomic) IBOutlet UILabel *monthlyPrice;
@property (weak, nonatomic) IBOutlet UILabel *yearlyBonusLabel;
@property (weak, nonatomic) IBOutlet UILabel *yearlyPrice;

@property (weak, nonatomic) IBOutlet UITextView *termsAndConditionsTextView;
@property (weak, nonatomic) IBOutlet UIStackView *mainStack;

@property (weak, nonatomic) IBOutlet UIStackView *carouselStack;
@property (weak, nonatomic) IBOutlet ZKCarousel *carousel;
@property (weak, nonatomic) IBOutlet UILabel *reviewPerson1;
@property (weak, nonatomic) IBOutlet UILabel *reviewPerson2;
@property (weak, nonatomic) IBOutlet UILabel *reviewPerson3;
@property (weak, nonatomic) IBOutlet UILabel *reviewPerson4;
@property (weak, nonatomic) IBOutlet UILabel *reviewPerson5;

@property (weak, nonatomic) IBOutlet UIButton *buttonRestorePrevious;

@property (weak, nonatomic) IBOutlet UIStackView *stackSale;
@property (weak, nonatomic) IBOutlet UILabel *labelSaleTimeRemaining;
@property (weak, nonatomic) IBOutlet UIView *freeTrialBadge;
@property (weak, nonatomic) IBOutlet UILabel *labelFirstMonthsFree;

@end

@implementation UpgradeViewController

+ (instancetype)fromStoryboard {
    UIStoryboard* storyboard = [UIStoryboard storyboardWithName:@"Upgrade" bundle:nil];
    UpgradeViewController* vc = [storyboard instantiateInitialViewController];
    
    vc.modalPresentationStyle = UIModalPresentationFullScreen;
    vc.modalInPresentation = YES;
    
    return vc;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    [self setupUi];
    
    [self bindUi];
    
    ProUpgradeIAPManager.sharedInstance.productsAvailableNotify = ^{
        dispatch_async(dispatch_get_main_queue(), ^(void) {
            [self bindUi];
        });
    };
    
    [ProUpgradeIAPManager.sharedInstance initialize]; 
}

- (void)setupUi {
    [self setupCarousel];
    
    [self setupReviews];
    
    [self setupPricing];
    
    [self fixStrangeTermsAndConditions];
    
    [self.mainStack setCustomSpacing:0.0 afterView:self.carouselStack];
    
    self.presentationController.delegate = self;
}

- (void)setupCarousel {
    NSString* fmt = BiometricsManager.sharedInstance.isFaceId ? NSLocalizedString(@"upgrade_vc_feature_face_id_pin_code", @"Face ID & PIN Code Unlock") :
                                                                NSLocalizedString(@"upgrade_vc_feature_touch_id_pin_code", @"Touch ID & PIN Code Unlock");
    
    ZKCarouselSlide* biometricUnlock = [[ZKCarouselSlide alloc] initWithImage:[self getRoundedImage:@"upgrade_carousel_face_id"]
                                                                        title:fmt
                                                                         body:NSLocalizedString(@"upgrade_vc_feature_subtitle_biometric", @"Super Fast, Secure & Convenient")
                                                                         tint:UIColor.whiteColor];

    ZKCarouselSlide* yubikey = [[ZKCarouselSlide alloc] initWithImage:[self getRoundedImage:@"upgrade_carousel_yubikey4"]
                                                               title:@"YubiKey"
                                                                body:NSLocalizedString(@"upgrade_vc_feature_subtitle_yubikey", @"Use a YubiKey as a second factor")
                                                                tint:UIColor.whiteColor];
    
    ZKCarouselSlide* auditing = [[ZKCarouselSlide alloc] initWithImage:[self getRoundedImage:@"upgrade_carousel_auditing"]
                                                               title:NSLocalizedString(@"upgrade_vc_feature_auditing", @"Advanced Auditing")
                                                                body:NSLocalizedString(@"upgrade_vc_feature_subtitle_auditing", @"HIBP & Similar Passwords")
                                                                tint:UIColor.whiteColor];

    ZKCarouselSlide* support = [[ZKCarouselSlide alloc] initWithImage:[self getRoundedImage:@"upgrade_carousel_support"]
                                                               title:NSLocalizedString(@"upgrade_vc_feature_support", @"Premium Support")
                                                                body:NSLocalizedString(@"upgrade_vc_feature_subtitle_support", @"We're here for you")
                                                                tint:UIColor.whiteColor];

    ZKCarouselSlide* compare = [[ZKCarouselSlide alloc] initWithImage:[self getRoundedImage:@"upgrade_carousel_compare"]
                                                               title:NSLocalizedString(@"upgrade_vc_feature_compare_and_merge", @"Compare & Merge")
                                                                body:NSLocalizedString(@"upgrade_vc_feature_subtitle_compare_and_merge", @"View & Combine Revisions")
                                                                tint:UIColor.whiteColor];

    UIImage* image = [UIImage systemImageNamed:@"bolt.circle.fill"];
    
    ZKCarouselSlide* offline = [[ZKCarouselSlide alloc] initWithImage:image
                                                                title:NSLocalizedString(@"upgrade_vc_feature_offline_editing", @"Offline Editing")
                                                                 body:NSLocalizedString(@"upgrade_vc_feature_subtitle_offline_editing", @"Edit Offline, Sync Later")
                                                                 tint:UIColor.systemYellowColor];
    
    ZKCarouselSlide* customAppIcons = [[ZKCarouselSlide alloc] initWithImage:[self getRoundedImage:@"upgrade_carousel_custom_app_icon"]
                                                                       title:NSLocalizedString(@"upgrade_vc_feature_custom_app_icon", @"Custom App Icons")
                                                                        body:NSLocalizedString(@"upgrade_vc_feature_subtitle_custom_app_icon", @"Customize your Strongbox")
                                                                        tint:UIColor.whiteColor];
    
    ZKCarouselSlide* favIconDownloader = [[ZKCarouselSlide alloc] initWithImage:[self getRoundedImage:@"upgrade_carousel_favicon"]
                                                                          title:NSLocalizedString(@"upgrade_vc_feature_favicon_downloader", @"Favicon Downloader")
                                                                           body:NSLocalizedString(@"upgrade_vc_feature_subtitle_favicon_downloader", @"Make your entries stand out")
                                                                           tint:UIColor.whiteColor];

    UIImage* image2 = [UIImage systemImageNamed:@"heart.circle"];

    ZKCarouselSlide* indieDev = [[ZKCarouselSlide alloc] initWithImage:image2
                                                                 title:NSLocalizedString(@"upgrade_vc_feature_support_indie", @"Support Indie Development")
                                                                  body:NSLocalizedString(@"upgrade_vc_feature_subtitle_support_indie", @"Help us stay awesome!")
                                                                  tint:UIColor.systemPurpleColor];
    
    NSMutableArray* mutSlides = @[
        biometricUnlock,
        customAppIcons,
        compare,
        indieDev,
        support,
        auditing,
        favIconDownloader,
        offline,
    ].mutableCopy;
    
    if ( !Utils.isiPadPro ) {
        [mutSlides insertObject:yubikey atIndex:0];
    }
    
    self.carousel.slides = mutSlides;
    
    self.carousel.interval = 5.0;
    [self.carousel start];
}

- (void)setupReviews {
    const CGFloat kRadius = 15.0f;

    self.reviewPerson1.layer.cornerRadius = kRadius;
    self.reviewPerson1.clipsToBounds = YES;

    self.reviewPerson2.layer.cornerRadius = kRadius;
    self.reviewPerson2.clipsToBounds = YES;

    self.reviewPerson3.layer.cornerRadius = kRadius;
    self.reviewPerson3.clipsToBounds = YES;

    self.reviewPerson4.layer.cornerRadius = kRadius;
    self.reviewPerson4.clipsToBounds = YES;

    self.reviewPerson5.layer.cornerRadius = kRadius;
    self.reviewPerson5.clipsToBounds = YES;
}

- (void)setupPricing {
    const CGFloat kRadius = 10.0f;
    
    self.buttonViewMonthly.layer.cornerRadius = kRadius;
    
    if ( self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark ) {
        self.buttonViewMonthly.backgroundColor = UIColor.systemGray5Color;
    }
    else {
        self.buttonViewMonthly.backgroundColor = UIColor.systemGray5Color;
    }
    
    self.buttonViewYearly.layer.cornerRadius = kRadius;

    UITapGestureRecognizer *m = [[UITapGestureRecognizer alloc] initWithTarget:self
                                                                        action:@selector(onMonthly)];
    [self.buttonViewMonthly addGestureRecognizer:m];

    UITapGestureRecognizer *y = [[UITapGestureRecognizer alloc] initWithTarget:self
                                                                        action:@selector(onYearly)];
    [self.buttonViewYearly addGestureRecognizer:y];
    
    [self customizeFreeTrialBadge];
}

- (void)customizeFreeTrialBadge {
    UIBezierPath* bezierPath = [UIBezierPath bezierPath];
    
    CGFloat width = self.freeTrialBadge.frame.size.width;
    CGFloat height = self.freeTrialBadge.frame.size.height;
    CGFloat foo = height * 0.7;
    
    
    [bezierPath moveToPoint:CGPointMake(0, foo)];
    
    
    [bezierPath addLineToPoint:CGPointMake(width/2, height)];
    
    
    [bezierPath addLineToPoint:CGPointMake(width, foo)];
    
    
    [bezierPath addLineToPoint:CGPointMake(width, 0)];
    
    
    [bezierPath addLineToPoint:CGPointMake(0, 0)];
    
    bezierPath.lineJoinStyle = kCGLineJoinRound;

    
    [bezierPath closePath];

    
    CAShapeLayer *mask = [CAShapeLayer layer];
    
    
    
    mask.path = bezierPath.CGPath;
    
    
    
    self.freeTrialBadge.layer.mask = mask;
}

- (void)fixStrangeTermsAndConditions {
    
    
    static NSString* const kTextViewInterfaceBuilderId = @"k2u-lE-LrX.text";
    NSString *tc = NSLocalizedStringFromTable(kTextViewInterfaceBuilderId, @"Upgrade", @"");
    if (tc && ![tc isEqualToString:kTextViewInterfaceBuilderId]) {
        self.termsAndConditionsTextView.text = tc;
    }
}

- (void)bindUi {
    [self bindMonthlyPricing];
    [self bindYearlyPricing];
    [self bindSale];
}

- (void)bindSale {
    
    self.stackSale.hidden = YES; 
















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
    self.labelFirstMonthsFree.hidden = YES;
    self.yearlyBonusLabel.text = @"";
    self.buttonViewYearly.userInteractionEnabled = NO;
    
    SKProduct* product = ProUpgradeIAPManager.sharedInstance.yearlyProduct;
    if ( state == kReady && product ) {
        SKProduct* monthlyProduct = ProUpgradeIAPManager.sharedInstance.monthlyProduct;
        
        NSString * bonusText;
        if(monthlyProduct) {
            int percentSavings = calculatePercentageSavings([self getEffectivePrice:product], [self getEffectivePrice:monthlyProduct], 12);
            bonusText = [NSString stringWithFormat:NSLocalizedString(@"upgrade_vc_price_per_month_with_percentage_saving_fmt2", @"%@ / month (Save %@%%)"), [self getPriceTextFromProduct:product divisor:12], @(percentSavings)];
        }
        else {
            bonusText = [NSString stringWithFormat:NSLocalizedString(@"upgrade_vc_price_per_month_fmt", @"%@ / month"), [self getPriceTextFromProduct:product divisor:12]];
        }
        NSString* priceText = [self getPriceTextFromProduct:product];
        
        NSString* fmt;
        if ( ProUpgradeIAPManager.sharedInstance.isFreeTrialAvailable ) {
            self.freeTrialBadge.hidden = NO;
            fmt = [NSString stringWithFormat:NSLocalizedString(@"upgrade_vc_price_per_year_with_free_trial_fmt", @"then %@ every year"), priceText];
            self.yearlyBonusLabel.hidden = YES;
            self.labelFirstMonthsFree.hidden = NO;
        }
        else {
            self.freeTrialBadge.hidden = YES;
            fmt = [NSString stringWithFormat:NSLocalizedString(@"upgrade_vc_price_per_year_fmt", @"%@ / year"), priceText];
            self.yearlyBonusLabel.hidden = NO;
            self.labelFirstMonthsFree.hidden = YES;
        }
        
        self.yearlyPrice.text = fmt;
        self.yearlyBonusLabel.text = bonusText;
        
        self.buttonViewYearly.userInteractionEnabled = YES;
    }
    else if(state == kCouldNotGetProducts) {
        self.yearlyPrice.text = NSLocalizedString(@"upgrade_vc_price_not_currently_available", @"Unavailable... Check your network connection");
    }
}



- (IBAction)onLifer:(id)sender {
    SKStoreProductViewController *vc = [[SKStoreProductViewController alloc] init];
    
    [vc loadProductWithParameters:@{ SKStoreProductParameterITunesItemIdentifier : @(1481853033) }
                  completionBlock:^(BOOL result, NSError * _Nullable error) {
        if ( !result ) {
            slog(@"loadProductWithParameters: result = %hhd, error = %@", result, error);
        }
    }];
    
    [self presentViewController:vc animated:YES completion:nil];
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
                if( !AppPreferences.sharedInstance.isPro ) {
                    [self tryRefreshReceiptAfterRestorePurchases];
                }
                else {
                    [self dismiss];
                }
            }
        });
    }];
}

- (void)tryRefreshReceiptAfterRestorePurchases {
    [ProUpgradeIAPManager.sharedInstance refreshReceiptAndCheckForProEntitlements:^{
        dispatch_async(dispatch_get_main_queue(), ^(void) {
            if( !AppPreferences.sharedInstance.isPro ) {
                [Alerts info:self
                       title:NSLocalizedString(@"upgrade_vc_restore_unsuccessful_title", @"Restoration Unsuccessful")
                     message:NSLocalizedString(@"upgrade_vc_restore_unsuccessful_message", @"Upgrade could not be restored from previous purchase. Are you sure you have purchased this item?")
                  completion:nil];
            }
            else {
                [self dismiss];
            }
        });

    }];
}

- (void)onMonthly {
    [self purchase:ProUpgradeIAPManager.sharedInstance.monthlyProduct];
}

- (void)onYearly {
    [self purchase:ProUpgradeIAPManager.sharedInstance.yearlyProduct];
}

- (void)purchase:(SKProduct*)product {
    if ( ProUpgradeIAPManager.sharedInstance.state != kReady || product == nil ) {
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

            if ( error == nil ) { 
                dispatch_async(dispatch_get_main_queue(), ^(void) {
                    [self dismiss];
                });
            }
            else if ( error.code != SKErrorPaymentCancelled ) {
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
    self.buttonRestorePrevious.enabled = enable;
}

- (UIImage*)getRoundedImage:(NSString*)name {
    UIImage* img = [UIImage imageNamed:name];
    
    if ( img != nil ) {
        return [Utils makeRoundedImage:img radius:30];
    }
    
    return nil;
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

static int calculatePercentageSavings(NSDecimalNumber* price, NSDecimalNumber* monthlyPrice, int numberOfMonths) {
    NSDecimalNumber* div = [NSDecimalNumber decimalNumberWithMantissa:numberOfMonths exponent:0 isNegative:NO];
    NSDecimalNumber* monthlyCalculatedPrice = [price decimalNumberByDividingBy:div];

    NSDecimalNumber *oneHundred = [NSDecimalNumber decimalNumberWithMantissa:100 exponent:0 isNegative:NO];
    NSDecimalNumber *num = [[monthlyPrice decimalNumberBySubtracting:monthlyCalculatedPrice] decimalNumberByMultiplyingBy:oneHundred];
    
    return [[num decimalNumberByDividingBy:monthlyPrice] intValue];
}

- (IBAction)onFreeProComparisonChart:(id)sender {
    [UIApplication.sharedApplication openURL:[NSURL URLWithString:@"https:
                                     options:@{}
                           completionHandler:^(BOOL success) {
        if (!success) {
            slog(@"Couldn't launch this URL!");
        }
    }];
}

- (IBAction)onNoThanks:(id)sender {
    [self dismiss];
}

- (void)presentationControllerDidDismiss:(UIPresentationController *)presentationController {


    if ( self.onDone ) {
        self.onDone();
    }
}

- (void)dismiss {
    [SVProgressHUD dismiss];
    
    [self.presentingViewController dismissViewControllerAnimated:YES completion:^{
        if ( self.onDone ) {
            self.onDone();
        }
    }];
}

@end

