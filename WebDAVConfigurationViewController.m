//
//  WebDAVConfigurationViewController.m
//  Strongbox
//
//  Created by Mark on 12/12/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
//

#import "WebDAVConfigurationViewController.h"

@interface WebDAVConfigurationViewController ()

@property (weak, nonatomic) IBOutlet UITextField *textFieldRootUrl;
@property (weak, nonatomic) IBOutlet UITextField *textFieldUsername;
@property (weak, nonatomic) IBOutlet UITextField *textFieldPassword;
@property (weak, nonatomic) IBOutlet UILabel *labelValidation;
@property (weak, nonatomic) IBOutlet UIButton *buttonConnect;
@property (weak, nonatomic) IBOutlet UISwitch *switchAllowUntrusted;

@end

@implementation WebDAVConfigurationViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    [self validateConnect];
}

- (IBAction)onConnect:(id)sender {
    self.configuration = [[WebDAVSessionConfiguration alloc] init];

    NSString* host = [self.textFieldRootUrl.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];

    self.configuration.host = [NSURL URLWithString:host];
    self.configuration.username = self.textFieldUsername.text;
    self.configuration.password = self.textFieldPassword.text;
    self.configuration.allowUntrustedCertificate = self.switchAllowUntrusted.on;
    
    self.onDone(YES);
}

- (IBAction)onCancel:(id)sender {
    self.onDone(NO);
}

- (IBAction)onTextFieldChanged:(id)sender {
    [self validateConnect];
}

- (void)validateConnect {
    NSString* host = [self.textFieldRootUrl.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    NSURL *urlHost = [NSURL URLWithString:host];
    
    if(!(urlHost && urlHost.scheme && urlHost.host)) {
        self.labelValidation.text = @"🛑 URL Invalid";
        self.labelValidation.textColor = [UIColor redColor];
        self.buttonConnect.enabled = NO;
        return;
    }
    
    self.labelValidation.text = @"✅ Looks Good";
    self.buttonConnect.enabled = YES;
    return;
}

@end
