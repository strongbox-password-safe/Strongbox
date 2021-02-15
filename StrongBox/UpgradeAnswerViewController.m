//
//  UpgradeAnswerViewController.m
//  Strongbox-iOS
//
//  Created by Mark on 14/03/2020.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import "UpgradeAnswerViewController.h"

@interface UpgradeAnswerViewController ()
@property (weak, nonatomic) IBOutlet UILabel *questionLabel;
@property (weak, nonatomic) IBOutlet UITextView *answerText;

@end

@implementation UpgradeAnswerViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.questionLabel.text = self.question;
    self.answerText.text = self.answer;
}

- (IBAction)onDone:(id)sender {
    [self.presentingViewController dismissViewControllerAnimated:YES completion:nil];
}

@end
