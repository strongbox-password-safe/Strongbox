//
//  MasterPasswordExplanationViewController.m
//  Strongbox
//
//  Created by Strongbox on 08/10/2021.
//  Copyright © 2021 Mark McGuill. All rights reserved.
//

#import "MasterPasswordExplanationViewController.h"
#import "WelcomeMasterPasswordViewController.h"

@interface MasterPasswordExplanationViewController ()

@property (weak, nonatomic) IBOutlet UIImageView *imageView;

@end

@implementation MasterPasswordExplanationViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    self.imageView.image = [UIImage systemImageNamed:@"lock.shield"];
}

- (IBAction)onGotIt:(id)sender {
    [self performSegueWithIdentifier:@"segueToMasterPasswordEntry" sender:nil];
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if([segue.identifier isEqualToString:@"segueToMasterPasswordEntry"]) {
        WelcomeMasterPasswordViewController* vc = (WelcomeMasterPasswordViewController*)segue.destinationViewController;
        
        vc.name = self.name;
        vc.onDone = self.onDone;
    }
}


@end
