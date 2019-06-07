//
//  ProExplanationViewController.m
//  Strongbox-iOS
//
//  Created by Mark on 07/06/2019.
//  Copyright © 2019 Mark McGuill. All rights reserved.
//

#import "ProExplanationViewController.h"

@interface ProExplanationViewController ()

@property (weak, nonatomic) IBOutlet UIButton *buttonGotIt;
@property (weak, nonatomic) IBOutlet UIButton *alternateGotIt;

@end

@implementation ProExplanationViewController

- (BOOL)shouldAutorotate {
    if ( UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad )
    {
        return YES; /* Device is iPad */
    }
    else {
        return NO;
    }
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    if ( UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad )
    {
        return UIInterfaceOrientationMaskAll; /* Device is iPad */
    }
    else {
        return UIInterfaceOrientationMaskPortrait;
    }
}

- (void)viewDidLoad {
    [super viewDidLoad];

    self.buttonGotIt.layer.cornerRadius = 5;
    
    self.alternateGotIt.hidden = UI_USER_INTERFACE_IDIOM() != UIUserInterfaceIdiomPad;
}

- (IBAction)onGotIt:(id)sender {
    [self.presentingViewController dismissViewControllerAnimated:YES completion:nil];
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
