//
//  UpgradeTableController.h
//  
//
//  Created by Mark on 16/07/2017.
//
//

#import <UIKit/UIKit.h>

@interface UpgradeViewController : UIViewController

- (IBAction)onUpgrade:(id)sender;
@property (weak, nonatomic) IBOutlet UIButton *buttonUpgrade2; // TODO: Broken
@property (weak, nonatomic) IBOutlet UIButton *buttonNope;
@property (weak, nonatomic) IBOutlet UIButton *buttonRestore;
@property (weak, nonatomic) IBOutlet UILabel *labelBiometricIdFeature;

@property (weak, nonatomic) IBOutlet UIView *sub1View;
@property (weak, nonatomic) IBOutlet UIView *sub2View;
@property (weak, nonatomic) IBOutlet UIView *sub3View;
@property (weak, nonatomic) IBOutlet UIView *sub4View;
@property (weak, nonatomic) IBOutlet UIStackView *comparisonChartStackView;
@property (weak, nonatomic) IBOutlet UIScrollView *scollViewComparisonChart;

@end
