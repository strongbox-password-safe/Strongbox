//
//  WelcomeCreateDoneViewController.m
//  Strongbox-iOS
//
//  Created by Mark on 05/06/2019.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import "WelcomeCreateDoneViewController.h"

@interface WelcomeCreateDoneViewController ()

@property (weak, nonatomic) IBOutlet UIButton *buttonOpen;
@property (weak, nonatomic) IBOutlet UILabel *labelWarning;

@end

@implementation WelcomeCreateDoneViewController

- (BOOL)shouldAutorotate {
    return UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad;
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad ? UIInterfaceOrientationMaskAll : UIInterfaceOrientationMaskPortrait;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    self.navigationController.navigationBar.hidden = YES;
    [self.navigationController setNavigationBarHidden:YES];
    
    self.navigationController.toolbarHidden = YES;
    self.navigationController.toolbar.hidden = YES;
    
    [self.navigationItem setPrompt:nil];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.buttonOpen.layer.cornerRadius = 5.0f;

    self.labelWarning.hidden = self.database.storageProvider != kLocalDevice;
}

- (IBAction)onOpen:(id)sender {
    self.onDone(NO, self.database);
}

- (IBAction)onPrintMasterPassword:(id)sender {
    NSString* htmlString = [NSString stringWithFormat:@"<html><body><h2><u>%@ Master Password</u></h2></p><h3><p><font face=\"Menlo\">%@</font></p></h3></body></html>", self.database.nickName, self.password];
    
    UIMarkupTextPrintFormatter *formatter = [[UIMarkupTextPrintFormatter alloc] initWithMarkupText:htmlString];

    UIPrintInteractionController.sharedPrintController.printFormatter = formatter;

    [UIPrintInteractionController.sharedPrintController presentAnimated:YES completionHandler:nil];
}

- (IBAction)onViewAllDatabases:(id)sender {
    self.onDone(NO, nil);
}

@end
