//
//  DuplicateOptionsViewController.m
//  Strongbox
//
//  Created by Strongbox on 01/08/2021.
//  Copyright © 2021 Mark McGuill. All rights reserved.
//

#import "DuplicateOptionsViewController.h"
#import "AppPreferences.h"

@interface DuplicateOptionsViewController ()

@property (weak, nonatomic) IBOutlet UISwitch *switchRefererencePassword;
@property (weak, nonatomic) IBOutlet UISwitch *switchReferenceUsername;
@property (weak, nonatomic) IBOutlet UISwitch *switchPreserveTimestamp;

@property (weak, nonatomic) IBOutlet UITableViewCell *cellReferencePassword;
@property (weak, nonatomic) IBOutlet UITableViewCell *cellReferenceUsername;
@property (weak, nonatomic) IBOutlet UITableViewCell *cellPreserveTimestamps;

@property (weak, nonatomic) IBOutlet UITextField *textFieldTitle;
@property (weak, nonatomic) IBOutlet UISwitch *switchEditAfter;

@end

@implementation DuplicateOptionsViewController

+ (instancetype)instantiate {
    UIStoryboard* storyboard = [UIStoryboard storyboardWithName:@"DuplicateItemOptions" bundle:nil];
    
    UINavigationController* nav  = [storyboard instantiateInitialViewController];
    
    return (DuplicateOptionsViewController*)nav.topViewController;
}

- (void)presentFromViewController:(UIViewController *)viewController {
    [viewController presentViewController:self.navigationController animated:YES completion:nil];
}

- (void)viewDidLoad {
    [super viewDidLoad];

    self.textFieldTitle.text = self.initialTitle;
    
    [self bindUi];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    [self.textFieldTitle becomeFirstResponder];
}

- (IBAction)onToggleReferencePassword:(id)sender {
    AppPreferences.sharedInstance.duplicateItemReferencePassword = !AppPreferences.sharedInstance.duplicateItemReferencePassword;
    
    [self bindUi];
}

- (IBAction)onToggleReferenceUsername:(id)sender {
    AppPreferences.sharedInstance.duplicateItemReferenceUsername = !AppPreferences.sharedInstance.duplicateItemReferenceUsername;
    
    [self bindUi];
}

- (IBAction)onTogglePreserveTimestamps:(id)sender {
    AppPreferences.sharedInstance.duplicateItemPreserveTimestamp = !AppPreferences.sharedInstance.duplicateItemPreserveTimestamp;
    
    [self bindUi];
}

- (IBAction)onToggleEditAfter:(id)sender {
    AppPreferences.sharedInstance.duplicateItemEditAfterwards = !AppPreferences.sharedInstance.duplicateItemEditAfterwards;
    
    [self bindUi];
}

- (void)bindUi {
    self.switchRefererencePassword.on = AppPreferences.sharedInstance.duplicateItemReferencePassword;
    self.switchReferenceUsername.on = AppPreferences.sharedInstance.duplicateItemReferenceUsername;
    self.switchPreserveTimestamp.on = AppPreferences.sharedInstance.duplicateItemPreserveTimestamp;
    self.switchEditAfter.on = AppPreferences.sharedInstance.duplicateItemEditAfterwards;
    
    [self cell:self.cellReferencePassword setHidden:!self.showFieldReferencingOptions];
    [self cell:self.cellReferenceUsername setHidden:!self.showFieldReferencingOptions];
    
    [self reloadDataAnimated:YES];
}

- (IBAction)onCancel:(id)sender {
    [self.presentingViewController dismissViewControllerAnimated:YES completion:^{
        self.completion(NO, NO, NO, NO, self.initialTitle, NO);
    }];
}

- (IBAction)onDuplicate:(id)sender {
    [self.presentingViewController dismissViewControllerAnimated:YES completion:^{
        BOOL refPw = self.showFieldReferencingOptions && AppPreferences.sharedInstance.duplicateItemReferencePassword;
        BOOL refUser = self.showFieldReferencingOptions && AppPreferences.sharedInstance.duplicateItemReferenceUsername;
        BOOL timestamps = AppPreferences.sharedInstance.duplicateItemPreserveTimestamp;
        BOOL editAfter = AppPreferences.sharedInstance.duplicateItemEditAfterwards;
        
        self.completion(YES, refPw, refUser, timestamps, self.textFieldTitle.text, editAfter);
    }];
}

@end
