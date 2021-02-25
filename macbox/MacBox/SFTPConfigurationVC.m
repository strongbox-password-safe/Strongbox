//
//  SFTPConfigurationVC.m
//  MacBox
//
//  Created by Strongbox on 04/02/2021.
//  Copyright © 2021 Mark McGuill. All rights reserved.
//

#import "SFTPConfigurationVC.h"
#import "MacAlerts.h"
#import "BookmarksHelper.h"

@interface SFTPConfigurationVC () <NSWindowDelegate, NSControlTextEditingDelegate>

@property BOOL hasLoaded;

@property (weak) IBOutlet NSTextField* textFieldHost;
@property (weak) IBOutlet NSTextField* textFieldPath;
@property (weak) IBOutlet NSTextField* labelValidation;
@property (weak) IBOutlet NSTextField* textFieldUsername;
@property (weak) IBOutlet NSTextField* textFieldPassword;
@property (weak) IBOutlet NSButton* buttonConnect;
@property (weak) IBOutlet NSButton *buttonPrivateKey;
@property (weak) IBOutlet NSTextField *textFieldPrivateKey;

@property NSString* privateKey;

@end

@implementation SFTPConfigurationVC

+ (instancetype)newConfigurationVC {
    NSStoryboard* storyboard = [NSStoryboard storyboardWithName:@"SFTPConfigurationVC" bundle:nil];
    SFTPConfigurationVC* sharedInstance = [storyboard instantiateInitialController];
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
    self.buttonPrivateKey.state = NSControlStateValueOff;
    [self bindUi];
}

- (void)controlTextDidChange:(NSNotification *)notification {
    [self bindUi];
}

- (IBAction)onUsePrivateKey:(id)sender {
    if ( self.buttonPrivateKey.state == NSControlStateValueOn ) {
        [self onLocateKey:nil];
    }
    else {
        self.privateKey = nil;
    }
    
    [self bindUi];
}

- (void)bindUi {
    if (!self.privateKey) {
        self.textFieldPrivateKey.stringValue = @"";
    }
    
    self.buttonPrivateKey.state = self.privateKey ? NSControlStateValueOn : NSControlStateValueOff;
    
    [self validateConnect];
}

- (void)onLocateKey:(id)sender {
    NSOpenPanel *openPanel = [NSOpenPanel openPanel];
    openPanel.showsHiddenFiles = YES;
    [openPanel beginSheetModalForWindow:self.view.window completionHandler:^(NSInteger result){
        if (result == NSModalResponseOK) {
            NSLog(@"onLocateKey: %@", openPanel.URL);

            NSData* key = [NSData dataWithContentsOfURL:openPanel.URL];
            NSString* privateKey = [[NSString alloc] initWithData:key encoding:NSUTF8StringEncoding];

            if(privateKey != nil) {
                self.privateKey = privateKey;
                self.textFieldPrivateKey.stringValue = [openPanel.URL lastPathComponent];
            }
            else {
                [MacAlerts info:NSLocalizedString(@"sftp_vc_warn_invalid_key_title", @"Invalid Key")
                informativeText:NSLocalizedString(@"sftp_vc_warn_invalid_key_message", @"This does not look like a valid private key")
                         window:self.view.window
                     completion:nil];
            }
            








        }

        [self bindUi];
    }];
}

- (void)validateConnect {
    NSString* host = [self.textFieldHost.stringValue stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    
    if(!host.length) {
        self.labelValidation.stringValue = NSLocalizedString(@"sftp_vc_label_validation_enter_host", @"Please Enter a Host");
        self.labelValidation.textColor = [NSColor systemRedColor];
        self.buttonConnect.enabled = NO;
        return;
    }
        
    if((self.buttonPrivateKey.state == NSControlStateValueOn) && self.privateKey.length == 0) {
        self.labelValidation.stringValue = NSLocalizedString(@"sftp_vc_label_validation_select_private_key", @"Select a Private Key...");
        self.labelValidation.textColor = [NSColor systemRedColor];
        self.buttonConnect.enabled = NO;
        return;
    }

    NSString* path = self.textFieldPath.stringValue;
    if (path.pathExtension.length != 0) {
        self.labelValidation.stringValue = NSLocalizedString(@"sftp_path_are_you_sure", @"Are you sure the path is correct? It should be a path to a parent folder. Not the database file.");
        self.labelValidation.textColor = [NSColor systemOrangeColor];
        self.buttonConnect.enabled = YES;
    }
    else {
        self.labelValidation.stringValue = @"";
        self.buttonConnect.enabled = YES;
    }
    return;
}

- (IBAction)onConnect:(id)sender {
    SFTPSessionConfiguration* configuration = [[SFTPSessionConfiguration alloc] init];
    
    NSString* host = [self.textFieldHost.stringValue stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    NSString* path = self.textFieldPath.stringValue;
    
    if (path.pathExtension.length != 0) {
        [MacAlerts yesNo:NSLocalizedString(@"sftp_path_may_be_invalid", @"Path may be Invalid")
         informativeText:NSLocalizedString(@"sftp_path_are_you_sure", @"Are you sure the path is correct? It should be a path to a parent folder. Not the database file.")
                  window:self.view.window
              completion:^(BOOL yesNo) {
            if ( yesNo ) {
                configuration.host = host;
                configuration.username = self.textFieldUsername.stringValue;
                configuration.password = self.textFieldPassword.stringValue;
                configuration.authenticationMode = (self.buttonPrivateKey.state == NSControlStateValueOn) ? kPrivateKey : kUsernamePassword;
                configuration.privateKey = self.privateKey;
                configuration.initialDirectory = self.textFieldPath.stringValue;

                self.onDone(YES, configuration);
            }
        }];
    }
    else {
        configuration.host = host;
        configuration.username = self.textFieldUsername.stringValue;
        configuration.password = self.textFieldPassword.stringValue;
        configuration.authenticationMode = (self.buttonPrivateKey.state == NSControlStateValueOn) ? kPrivateKey : kUsernamePassword;
        configuration.privateKey = self.privateKey;
        configuration.initialDirectory = self.textFieldPath.stringValue;
        
        self.onDone(YES, configuration);
    }
    
    [self.presentingViewController dismissViewController:self];
}

- (IBAction)onCancel:(id)sender {
    self.onDone(NO, nil);
    [self.presentingViewController dismissViewController:self];
}

@end
