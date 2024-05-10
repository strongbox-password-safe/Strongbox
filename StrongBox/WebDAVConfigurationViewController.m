//
//  WebDAVConfigurationViewController.m
//  Strongbox
//
//  Created by Mark on 12/12/2018.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import "WebDAVConfigurationViewController.h"
#import "Utils.h"
#import "NSString+Extensions.h"
#import "Alerts.h"

#ifndef NO_NETWORKING
#import "WebDAVStorageProvider.h"
#endif

@interface WebDAVConfigurationViewController ()

@property (weak, nonatomic) IBOutlet UITextField *textFieldRootUrl;
@property (weak, nonatomic) IBOutlet UITextField *textFieldUsername;
@property (weak, nonatomic) IBOutlet UITextField *textFieldPassword;
@property (weak, nonatomic) IBOutlet UILabel *labelValidation;
@property (weak, nonatomic) IBOutlet UIButton *buttonConnect;
@property (weak, nonatomic) IBOutlet UISwitch *switchAllowUntrusted;
@property (weak, nonatomic) IBOutlet UITextField *textFieldName;

@end

@implementation WebDAVConfigurationViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    if ( self.initialConfiguration != nil ) { 
        self.textFieldName.text = self.initialConfiguration.name ? self.initialConfiguration.name : @"";
        self.textFieldRootUrl.text = self.initialConfiguration.host.absoluteString;
        self.textFieldUsername.text = self.initialConfiguration.username;
        self.textFieldPassword.text = self.initialConfiguration.password;
        self.switchAllowUntrusted.on = self.initialConfiguration.allowUntrustedCertificate;
    }
    else {
        [self.textFieldName becomeFirstResponder];
    }
    
    [self validateConnect];
}

- (IBAction)onConnect:(id)sender {
    NSString* hostStr = trim(self.textFieldRootUrl.text);

    
    
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
                [self testConnectionAndFinish];
            }
        }];
    }
    else {
        [self testConnectionAndFinish];
    }
}

- (void)testConnectionAndFinish {
    NSString* name = trim(self.textFieldName.text);
    NSString* hostStr = trim(self.textFieldRootUrl.text);

    
    
    if([hostStr hasSuffix:@"/"]) {
        hostStr = [hostStr substringToIndex:hostStr.length - 1];
    }

    NSURL *urlHost = hostStr.urlExtendedParse;
    
    WebDAVSessionConfiguration* configuration = [[WebDAVSessionConfiguration alloc] init];

    if ( self.initialConfiguration ) {
        configuration.identifier = self.initialConfiguration.identifier;
    }
    
    configuration.name = name;
    configuration.host = urlHost;
    configuration.username = self.textFieldUsername.text;
    configuration.password = self.textFieldPassword.text;
    configuration.allowUntrustedCertificate = self.switchAllowUntrusted.on;
    
#ifndef NO_NETWORKING
    [WebDAVStorageProvider.sharedInstance testConnection:configuration viewController:self completion:^(NSError * _Nonnull error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if ( error ) {
                [Alerts error:self error:error];
            }
            else {
                self.onDone(YES, configuration);
            }
        });
    }];
#endif
}

- (IBAction)onCancel:(id)sender {
    self.onDone(NO, nil);
}

- (IBAction)onTextFieldChanged:(id)sender {
    [self validateConnect];
}

- (void)validateConnect {
    NSString* name = trim(self.textFieldName.text);
    NSString* host = trim(self.textFieldRootUrl.text);
    NSURL *urlHost = host.urlExtendedParse;

    if ( name.length == 0 ) {
        self.labelValidation.text = NSLocalizedString(@"connection_vc_name_invalid", @"Please enter a valid name.");
        self.labelValidation.textColor = [UIColor systemRedColor];
        self.buttonConnect.enabled = NO;
    }
    else if(!(urlHost && urlHost.scheme && urlHost.host)) {
        self.labelValidation.text = NSLocalizedString(@"webdav_vc_validation_url_invalid", @"URL Invalid");
        self.labelValidation.textColor = [UIColor systemRedColor];
        self.buttonConnect.enabled = NO;
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
