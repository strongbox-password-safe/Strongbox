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
@property WebDAVSessionConfiguration *draftConfiguration;
@property NSString* originalConnectTitle;

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
    
    self.originalConnectTitle = self.buttonConnect.title;
    [self.buttonConnect setTitle:NSLocalizedString(@"mac_save_action", @"Save")];

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
    
    [self validateConnect];
}

- (void)controlTextDidChange:(NSNotification *)notification {
    [self validateConnect];
}

- (IBAction)onAllowTrustedChanged:(id)sender {
    [self validateConnect];
}

- (void)validateConnect {
    NSString* name = trim(self.textFieldName.stringValue);
    NSString* host = trim(self.textFieldRootURL.stringValue);
    NSURL *urlHost = host.urlExtendedParse;

    BOOL valid = YES;
    
    if ( name.length == 0 ) {
        self.labelValidation.stringValue = NSLocalizedString(@"connection_vc_name_invalid", @"Please enter a valid name.");
        self.labelValidation.textColor = [NSColor systemRedColor];
        valid = NO;
    }
    else if(!(urlHost && urlHost.scheme && urlHost.host)) {
        self.labelValidation.stringValue = NSLocalizedString(@"webdav_vc_validation_url_invalid", @"URL Invalid");
        self.labelValidation.textColor = [NSColor systemRedColor];
        valid = NO;
    }
    else if (urlHost.lastPathComponent.pathExtension.length != 0) {
        self.labelValidation.stringValue = NSLocalizedString(@"webdav_vc_validation_url_are_you_sure", @"Are you sure the URL is correct? It should be a URL to a parent folder. Not the database file.");
        self.labelValidation.textColor = [NSColor systemOrangeColor];
    }
    else {
        self.labelValidation.stringValue = @"";
    }
    
    [self.buttonConnect setTitle:NSLocalizedString(@"mac_save_action", @"Save")];
    
    if ( self.initialConfiguration ) {
        [self updateDraftConfiguration];
        
        BOOL hasEdits = ![self.initialConfiguration isTheSameConnection:self.draftConfiguration];
        
        self.buttonConnect.enabled = valid && hasEdits;
        
        if ( ![self.initialConfiguration isNetworkingFieldsAreSame:self.draftConfiguration] ) {
            [self.buttonConnect setTitle:self.originalConnectTitle];
        }
    }
    else {
        [self.buttonConnect setTitle:self.originalConnectTitle];
        self.buttonConnect.enabled = valid;
    }
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

- (void)updateDraftConfiguration {
    NSString* name = trim(self.textFieldName.stringValue);
    NSString* hostStr = trim(self.textFieldRootURL.stringValue);
    
    
    
    if([hostStr hasSuffix:@"/"]) {
        hostStr = [hostStr substringToIndex:hostStr.length - 1];
    }
    
    NSURL *urlHost = hostStr.urlExtendedParse;
    
    if ( self.draftConfiguration == nil ) {
        self.draftConfiguration = [[WebDAVSessionConfiguration alloc] init];
    }
    
    if ( self.initialConfiguration ) {
        self.draftConfiguration.identifier = self.initialConfiguration.identifier;
    }
    
    self.draftConfiguration.name = name;
    self.draftConfiguration.host = urlHost;
    self.draftConfiguration.username = self.textFieldUsername.stringValue;
    self.draftConfiguration.password = self.textFieldPassword.stringValue;
    self.draftConfiguration.allowUntrustedCertificate = self.buttonAllowUntrustedCert.state == NSControlStateValueOn;
}

- (void)testConnectionAndFinish {
    [self updateDraftConfiguration];
    
    if ( ![self.initialConfiguration isNetworkingFieldsAreSame:self.draftConfiguration] ) {
        [WebDAVStorageProvider.sharedInstance testConnection:self.draftConfiguration viewController:self completion:^(NSError * _Nonnull error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if ( error ) {
                    [MacAlerts error:error window:self.view.window];
                }
                else {
                    self.onDone(YES, self.draftConfiguration);
                    [self.presentingViewController dismissViewController:self];
                }
            });
        }];
    }
    else {
        self.onDone(YES, self.draftConfiguration);
        [self.presentingViewController dismissViewController:self];
    }
}

@end
