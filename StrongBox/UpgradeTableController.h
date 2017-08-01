//
//  UpgradeTableController.h
//  
//
//  Created by Mark on 16/07/2017.
//
//

#import <UIKit/UIKit.h>
#import <StoreKit/StoreKit.h>

#define kIapProId @"com.markmcguill.strongbox.pro"
//#define kTestConsumable @"com.markmcguill.strongbox.testconsumable"

@interface UpgradeTableController : UITableViewController<SKPaymentTransactionObserver>

@property (nonatomic, strong) SKProduct *product;

- (IBAction)onUpgrade:(id)sender;
@property (weak, nonatomic) IBOutlet UIButton *buttonUpgrade2;
@property (weak, nonatomic) IBOutlet UIButton *buttonNope;

@end
