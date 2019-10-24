//
//  LargeTextViewController.m
//  Strongbox
//
//  Created by Mark on 23/10/2019.
//  Copyright © 2019 Mark McGuill. All rights reserved.
//

#import "LargeTextViewController.h"
#import "FontManager.h"

@interface LargeTextViewController ()

@property (weak, nonatomic) IBOutlet UILabel *labelLargeText;

@end

@implementation LargeTextViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    UITapGestureRecognizer *tapGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(labelTapped)];
    
    tapGestureRecognizer.numberOfTapsRequired = 1;
    
    [self.labelLargeText addGestureRecognizer:tapGestureRecognizer];
    self.labelLargeText.userInteractionEnabled = YES;

    self.labelLargeText.font = FontManager.sharedInstance.easyReadFontForTotp;
    self.labelLargeText.text = self.string;
}

- (void)labelTapped {
    [self.presentingViewController dismissViewControllerAnimated:YES completion:nil];
}

@end
