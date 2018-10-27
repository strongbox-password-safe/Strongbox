//
//  UpgradeTableController.h
//  
//
//  Created by Mark on 16/07/2017.
//
//

#import <UIKit/UIKit.h>
#import <StoreKit/StoreKit.h>

static NSString* const kIapProId =  @"com.markmcguill.strongbox.pro";
//kTestConsumable @"com.markmcguill.strongbox.testconsumable"

@interface UpgradeViewController : UIViewController<SKPaymentTransactionObserver, SKProductsRequestDelegate>

- (IBAction)onUpgrade:(id)sender;
@property (weak, nonatomic) IBOutlet UIButton *buttonUpgrade2;
@property (weak, nonatomic) IBOutlet UIButton *buttonNope;
@property (weak, nonatomic) IBOutlet UIButton *buttonRestore;
@property (weak, nonatomic) IBOutlet UILabel *labelBiometricIdFeature;

@end
