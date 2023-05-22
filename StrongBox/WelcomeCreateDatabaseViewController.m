//
//  WelcomeCreateDatabaseViewController.m
//  Strongbox-iOS
//
//  Created by Mark on 05/06/2019.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import "WelcomeCreateDatabaseViewController.h"
#import "DatabasePreferences.h"
#import "Utils.h"
#import "MasterPasswordExplanationViewController.h"

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

    self.textFieldName.text = DatabasePreferences.suggestedNewDatabaseName;
    
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
    self.nextButton.backgroundColor = enabled ? UIColor.systemBlueColor : UIColor.lightGrayColor;
}

- (BOOL)nameIsValid {
    NSString* sanitized = [DatabasePreferences trimDatabaseNickName:self.textFieldName.text];
    return [DatabasePreferences isValid:sanitized] && [DatabasePreferences isUnique:sanitized];
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if([segue.identifier isEqualToString:@"segueToMasterPassword"]) {
        MasterPasswordExplanationViewController* vc = (MasterPasswordExplanationViewController*)segue.destinationViewController;
        
        vc.name = [DatabasePreferences trimDatabaseNickName:self.textFieldName.text];
        vc.onDone = self.onDone;
    }
}

@end
