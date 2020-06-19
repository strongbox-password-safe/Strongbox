//
//  WebDAVConfigurationViewController.m
//  Strongbox
//
//  Created by Mark on 12/12/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
//

#import "WebDAVConfigurationViewController.h"
#import "Utils.h"
#import "NSString+Extensions.h"

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
    
    [self.textFieldRootUrl becomeFirstResponder];
}

- (IBAction)onConnect:(id)sender {
    self.configuration = [[WebDAVSessionConfiguration alloc] init];

    NSString* hostStr = trim(self.textFieldRootUrl.text);

    // Trim trailing Slash as library doesn't like it...
    
    if([hostStr hasSuffix:@"/"]) {
        hostStr = [hostStr substringToIndex:hostStr.length - 1];
    }

    self.configuration.host = hostStr.urlExtendedParse;
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
    NSString* host = trim(self.textFieldRootUrl.text);
    NSURL *urlHost = host.urlExtendedParse;
    
    if(!(urlHost && urlHost.scheme && urlHost.host)) {
        self.labelValidation.text = NSLocalizedString(@"webdav_vc_validation_url_invalid", @"URL Invalid");
        self.labelValidation.textColor = [UIColor systemRedColor];
        self.buttonConnect.enabled = NO;
        return;
    }
    
    self.labelValidation.text = @"";
    self.buttonConnect.enabled = YES;
    return;
}

@end
