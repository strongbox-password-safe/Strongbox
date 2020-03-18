//
//  FreeProChartViewController.m
//  Strongbox-iOS
//
//  Created by Mark on 12/03/2020.
//  Copyright © 2020 Mark McGuill. All rights reserved.
//

#import "FreeProChartViewController.h"
#import "BiometricsManager.h"

@interface FreeProChartViewController ()

@property (weak, nonatomic) IBOutlet UILabel *labelBiometrics;

@end

@implementation FreeProChartViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    NSString* loc = NSLocalizedString(@"db_management_biometric_unlock_fmt", @"%@ Unlock");
    NSString* fmt = [NSString stringWithFormat:loc, [BiometricsManager.sharedInstance getBiometricIdName]];
    self.labelBiometrics.text = fmt;
}

- (IBAction)onCancel:(id)sender {
    [self.presentingViewController dismissViewControllerAnimated:YES completion:nil];
}

@end
