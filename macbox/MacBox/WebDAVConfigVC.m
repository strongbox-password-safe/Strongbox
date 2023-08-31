//
//  WebDAVConfigVC.m
//  MacBox
//
//  Created by Strongbox on 17/02/2021.
//  Copyright © 2021 Mark McGuill. All rights reserved.
//

#import "WebDAVConfigVC.h"
#import "Utils.h"
#import "NSString+Extensions.h"
#import "MacAlerts.h"
#import "WebDAVStorageProvider.h"

@interface WebDAVConfigVC () <NSWindowDelegate, NSControlTextEditingDelegate>

@property BOOL hasLoaded;

@property (weak) IBOutlet NSTextField *textFieldName;
@property (weak) IBOutlet NSTextField *textFieldRootURL;
@property (weak) IBOutlet NSTextField *textFieldUsername;
@property (weak) IBOutlet NSSecureTextField *textFieldPassword;
@property (weak) IBOutlet NSButton *buttonAllowUntrustedCert;
@property (weak) IBOutlet NSButton *buttonConnect;
@property (weak) IBOutlet NSTextField *labelValidation;

@end

@implementation WebDAVConfigVC

+ (instancetype)newConfigurationVC {
    NSStoryboard* storyboard = [NSStoryboard storyboardWithName:@"WebDAVConfigVC" bundle:nil];
    WebDAVConfigVC* sharedInstance = [storyboard instantiateInitialController];
    return sharedInstance;
}

- (void)viewWillAppear {
    [super viewWillAppear];

    if(!self.hasLoaded) {
        self.hasLoaded = YES;
        [self doInitialSetup];
    }
}

- (void)doInitialSetup {
    self.view.window.delegate = self;
    
    if ( self.initialConfiguration != nil ) { 
        self.textFieldName.stringValue = self.initialConfiguration.name ? self.initialConfiguration.name : @"";
        self.textFieldRootURL.stringValue = self.initialConfiguration.host.absoluteString;
        self.textFieldUsername.stringValue = self.initialConfiguration.username;
        self.textFieldPassword.stringValue = self.initialConfiguration.password;
        self.buttonAllowUntrustedCert.state = self.initialConfiguration.allowUntrustedCertificate ? NSControlStateValueOn : NSControlStateValueOff;
    }
    else {
        [self.textFieldName becomeFirstResponder];
    }
    
    [self bindUi];
}

- (void)controlTextDidChange:(NSNotification *)notification {
    [self bindUi];
}

- (void)bindUi {
    [self validateConnect];
}

- (void)validateConnect {
    NSString* name = trim(self.textFieldName.stringValue);
    NSString* host = trim(self.textFieldRootURL.stringValue);
    NSURL *urlHost = host.urlExtendedParse;

    if ( name.length == 0 ) {
        self.labelValidation.stringValue = NSLocalizedString(@"connection_vc_name_invalid", @"Please enter a valid name.");
        self.labelValidation.textColor = [NSColor systemRedColor];
        self.buttonConnect.enabled = NO;
    }
    else if(!(urlHost && urlHost.scheme && urlHost.host)) {
        self.labelValidation.stringValue = NSLocalizedString(@"webdav_vc_validation_url_invalid", @"URL Invalid");
        self.labelValidation.textColor = [NSColor systemRedColor];
        self.buttonConnect.enabled = NO;
    }
    else if (urlHost.lastPathComponent.pathExtension.length != 0) {
        self.labelValidation.stringValue = NSLocalizedString(@"webdav_vc_validation_url_are_you_sure", @"Are you sure the URL is correct? It should be a URL to a parent folder. Not the database file.");
        self.labelValidation.textColor = [NSColor systemOrangeColor];
        self.buttonConnect.enabled = YES;
    }
    else {
        self.labelValidation.stringValue = @"";
        self.buttonConnect.enabled = YES;
    }
    
    return;
}

- (IBAction)onCancel:(id)sender {
    self.onDone(NO, nil);
    [self.presentingViewController dismissViewController:self]; 
}

- (IBAction)onConnect:(id)sender {
    NSString* hostStr = trim(self.textFieldRootURL.stringValue);

    if([hostStr hasSuffix:@"/"]) { 
        hostStr = [hostStr substringToIndex:hostStr.length - 1];
    }

    NSURL *urlHost = hostStr.urlExtendedParse;
        
    if (urlHost.lastPathComponent.pathExtension.length != 0) {
        [MacAlerts yesNo:NSLocalizedString(@"webdav_vc_validation_url_maybe_invalid", @"URL May Be Invalid")
         informativeText:NSLocalizedString(@"webdav_vc_validation_url_are_you_sure", @"Are you sure the URL is correct? It should be a URL to a parent folder. Not the database file.")
                  window:self.view.window completion:^(BOOL yesNo) {
            if (yesNo) {
                [self testConnectionAndFinish];
            }
        }];
    }
    else {
        [self testConnectionAndFinish];
    }
}

- (void)testConnectionAndFinish {
    NSString* name = trim(self.textFieldName.stringValue);
    NSString* hostStr = trim(self.textFieldRootURL.stringValue);

    
    
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
    configuration.username = self.textFieldUsername.stringValue;
    configuration.password = self.textFieldPassword.stringValue;
    configuration.allowUntrustedCertificate = self.buttonAllowUntrustedCert.state == NSControlStateValueOn;

    [WebDAVStorageProvider.sharedInstance testConnection:configuration viewController:self completion:^(NSError * _Nonnull error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if ( error ) {
                [MacAlerts error:error window:self.view.window];
            }
            else {
                self.onDone(YES, configuration);
                [self.presentingViewController dismissViewController:self];
            }
        });
    }];
}

@end
