//
//  AsyncUpdateResultViewController.m
//  Strongbox
//
//  Created by Strongbox on 29/03/2021.
//  Copyright © 2021 Mark McGuill. All rights reserved.
//

#import "AsyncUpdateResultViewController.h"

@interface AsyncUpdateResultViewController ()

@property (weak, nonatomic) IBOutlet UILabel *labelStatus;
@property (weak, nonatomic) IBOutlet UILabel *labelError;

@end

@implementation AsyncUpdateResultViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    self.labelStatus.text = self.result.userInteractionRequired ? NSLocalizedString(@"sync_status_user_interaction_required_title", @"User Interaction Required") : NSLocalizedString(@"generic_error", @"Error");
    self.labelStatus.textColor = self.result.userInteractionRequired ? UIColor.systemOrangeColor : UIColor.systemRedColor;
    self.labelError.hidden = self.result.error == nil;
    self.labelError.text = self.result.error ? self.result.error.localizedDescription : @"";
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    self.preferredContentSize = [self.view systemLayoutSizeFittingSize:UILayoutFittingCompressedSize];
}

- (IBAction)onRetry:(id)sender {
    [self.presentingViewController dismissViewControllerAnimated:YES completion:^{
        if ( self.onRetryClicked ) {
            self.onRetryClicked();
        }
    }];
}

@end
