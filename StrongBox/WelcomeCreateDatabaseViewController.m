//
//  WelcomeCreateDatabaseViewController.m
//  Strongbox-iOS
//
//  Created by Mark on 05/06/2019.
//  Copyright © 2019 Mark McGuill. All rights reserved.
//

#import "WelcomeCreateDatabaseViewController.h"
#import "CASGTableViewController.h"
#import "WelcomeMasterPasswordViewController.h"
#import "SafesList.h"
#import "Utils.h"

@interface WelcomeCreateDatabaseViewController () <UITextFieldDelegate>

@property (weak, nonatomic) IBOutlet UIButton *nextButton;
@property (weak, nonatomic) IBOutlet UITextField *textFieldName;

@end

@implementation WelcomeCreateDatabaseViewController

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

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

    self.navigationController.navigationBar.hidden = YES;
    [self.navigationController setNavigationBarHidden:YES];
    
    self.navigationController.toolbarHidden = YES;
    self.navigationController.toolbar.hidden = YES;
    
    [self.navigationItem setPrompt:nil];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    [self.textFieldName becomeFirstResponder];
}

- (void)viewDidLoad {
    [super viewDidLoad];

    self.nextButton.layer.cornerRadius = 5.0f;

    self.textFieldName.text = [SafesList.sharedInstance getSuggestedDatabaseNameUsingDeviceName];
    
    [self.textFieldName addTarget:self
                           action:@selector(validateUi)
                 forControlEvents:UIControlEventEditingChanged];
    
    self.textFieldName.delegate = self;
}

- (IBAction)onDismiss:(id)sender {
    self.onDone(NO, nil);
}

- (IBAction)onNext:(id)sender {
    if([self nameIsValid]) {
        [self performSegueWithIdentifier:@"segueToMasterPassword" sender:nil];
    }
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    if([self nameIsValid]) {
        [textField resignFirstResponder];
        [self onNext:nil];
    }

    return YES;
}

- (void)validateUi {
    BOOL enabled = [self nameIsValid];
    self.nextButton.enabled = enabled;
    self.nextButton.backgroundColor = enabled ? UIColor.blueColor : UIColor.lightGrayColor;
}

- (BOOL)nameIsValid {
    return [SafesList.sharedInstance isValidNickName:trim(self.textFieldName.text)];
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if([segue.identifier isEqualToString:@"segueToMasterPassword"]) {
        WelcomeMasterPasswordViewController* vc = (WelcomeMasterPasswordViewController*)segue.destinationViewController;
        
        vc.name = [SafesList sanitizeSafeNickName:self.textFieldName.text];
        vc.onDone = self.onDone;
    }
}

@end
