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
#import "Alerts.h"

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

    NSURL *urlHost = hostStr.urlExtendedParse;
    
    if (urlHost.lastPathComponent.pathExtension.length != 0) {
        [Alerts yesNo:self
                title:NSLocalizedString(@"webdav_vc_validation_url_maybe_invalid", @"URL May Be Invalid")
              message:NSLocalizedString(@"webdav_vc_validation_url_are_you_sure", @"Are you sure the URL is correct? It should be a URL to a parent folder. Not the database file.")
               action:^(BOOL response) {
            if (response) {
                self.configuration.host = urlHost;
                self.configuration.username = self.textFieldUsername.text;
                self.configuration.password = self.textFieldPassword.text;
                self.configuration.allowUntrustedCertificate = self.switchAllowUntrusted.on;
                self.onDone(YES);
            }
        }];
    }
    else {
        self.configuration.host = urlHost;
        self.configuration.username = self.textFieldUsername.text;
        self.configuration.password = self.textFieldPassword.text;
        self.configuration.allowUntrustedCertificate = self.switchAllowUntrusted.on;
        self.onDone(YES);
    }
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
    else if (urlHost.lastPathComponent.pathExtension.length != 0) {
        self.labelValidation.text = NSLocalizedString(@"webdav_vc_validation_url_are_you_sure", @"Are you sure the URL is correct? It should be a URL to a parent folder. Not the database file.");
        self.labelValidation.textColor = [UIColor systemOrangeColor];
        self.buttonConnect.enabled = YES;
    }
    else {
        self.labelValidation.text = @"";
        self.buttonConnect.enabled = YES;
    }
    return;
}

@end
