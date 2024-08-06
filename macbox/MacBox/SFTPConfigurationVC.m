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
#import "SFTPStorageProvider.h"
#import "Utils.h"

@interface SFTPConfigurationVC () <NSWindowDelegate, NSControlTextEditingDelegate>

@property BOOL hasLoaded;

@property (weak) IBOutlet NSTextField *textFieldName;
@property (weak) IBOutlet NSTextField* textFieldHost;
@property (weak) IBOutlet NSTextField* textFieldPath;
@property (weak) IBOutlet NSTextField* labelValidation;
@property (weak) IBOutlet NSTextField* textFieldUsername;
@property (weak) IBOutlet NSTextField* textFieldPassword;
@property (weak) IBOutlet NSButton* buttonConnect;
@property (weak) IBOutlet NSButton *buttonPrivateKey;
@property (weak) IBOutlet NSTextField *textFieldPrivateKey;

@property NSString* privateKey;
@property SFTPSessionConfiguration* draftConfiguration; 

@property NSString* originalConnectTitle;
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
    self.originalConnectTitle = self.buttonConnect.title;
    [self.buttonConnect setTitle:NSLocalizedString(@"mac_save_action", @"Save")];
    
    if ( self.initialConfiguration ) {
        self.textFieldName.stringValue = self.initialConfiguration.name ? self.initialConfiguration.name : @"";
        self.textFieldHost.stringValue = self.initialConfiguration.host;
        self.textFieldUsername.stringValue = self.initialConfiguration.username;
        
        NSString* pw = self.initialConfiguration.password ? self.initialConfiguration.password : @"";
        self.textFieldPassword.stringValue = pw;
        
        self.buttonPrivateKey.state = self.initialConfiguration.authenticationMode == kPrivateKey ? NSControlStateValueOn : NSControlStateValueOff;
        self.textFieldPath.stringValue = self.initialConfiguration.initialDirectory;
        
        self.privateKey = self.initialConfiguration.privateKey;
    }
    else {
        [self.textFieldName becomeFirstResponder];
    }
    
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
    if ( !self.privateKey ) {
        self.textFieldPrivateKey.stringValue = @"";
    }
    else {
        if ( self.textFieldPrivateKey.stringValue.length == 0 ) {
            self.textFieldPrivateKey.placeholderString = NSLocalizedString(@"casg_key_file_configured", @"Configured");
        }
    }
    
    self.buttonPrivateKey.state = self.privateKey ? NSControlStateValueOn : NSControlStateValueOff;
    
    [self validateConnect];
}

- (void)onLocateKey:(id)sender {
    NSOpenPanel *openPanel = [NSOpenPanel openPanel];
    openPanel.showsHiddenFiles = YES;
    [openPanel beginSheetModalForWindow:self.view.window completionHandler:^(NSInteger result){
        if (result == NSModalResponseOK) {


            NSError* error;
            NSData* key = [NSData dataWithContentsOfURL:openPanel.URL options:kNilOptions error:&error];
            
            if ( key == nil ) {
                slog(@"Error: [%@]", error);
                [MacAlerts error:error window:self.view.window];
            }
            else {
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
        }

        [self bindUi];
    }];
}

- (void)validateConnect {
    BOOL ok;
    
    NSString* name = trim(self.textFieldName.stringValue);
    NSString* host = [self.textFieldHost.stringValue stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    NSString* path = self.textFieldPath.stringValue;

    if ( name.length == 0 ) {
        self.labelValidation.stringValue = NSLocalizedString(@"connection_vc_name_invalid", @"Please enter a valid name.");
        self.labelValidation.textColor = [NSColor systemRedColor];
        ok = NO;
    }
    else if( !host.length ) {
        self.labelValidation.stringValue = NSLocalizedString(@"sftp_vc_label_validation_enter_host", @"Please Enter a Host");
        self.labelValidation.textColor = [NSColor systemRedColor];
        ok = NO;
    }
    else if((self.buttonPrivateKey.state == NSControlStateValueOn) && self.privateKey.length == 0) {
        self.labelValidation.stringValue = NSLocalizedString(@"sftp_vc_label_validation_select_private_key", @"Select a Private Key...");
        self.labelValidation.textColor = [NSColor systemRedColor];
        ok = NO;
    }
    else if (path.pathExtension.length != 0) {
        self.labelValidation.stringValue = NSLocalizedString(@"sftp_path_are_you_sure", @"Are you sure the path is correct? It should be a path to a parent folder. Not the database file.");
        self.labelValidation.textColor = [NSColor systemOrangeColor];
        ok = YES;
    }
    else {
        self.labelValidation.stringValue = @"";
        ok = YES;
    }
    
    [self.buttonConnect setTitle:NSLocalizedString(@"mac_save_action", @"Save")];
    
    if ( self.initialConfiguration && ok ) {
        [self updateDraftConfiguration];
        
        BOOL configHasEdits = ![self.initialConfiguration isTheSameConnection:self.draftConfiguration];
        
        self.buttonConnect.enabled = ok && configHasEdits;
        
        if ( configHasEdits ) {
            if ( [self.initialConfiguration isNetworkingFieldsAreSame:self.draftConfiguration] ) {
                [self.buttonConnect setTitle:NSLocalizedString(@"mac_save_action", @"Save")];
            }
            else {
                [self.buttonConnect setTitle:self.originalConnectTitle];
            }
        }
    }
    else {
        [self.buttonConnect setTitle:self.originalConnectTitle];
        self.buttonConnect.enabled = ok;
    }
}

- (IBAction)onConnect:(id)sender {
    NSString* path = self.textFieldPath.stringValue;
    
    if (path.pathExtension.length != 0) {
        [MacAlerts yesNo:NSLocalizedString(@"sftp_path_may_be_invalid", @"Path may be Invalid")
         informativeText:NSLocalizedString(@"sftp_path_are_you_sure", @"Are you sure the path is correct? It should be a path to a parent folder. Not the database file.")
                  window:self.view.window
              completion:^(BOOL yesNo) {
            if ( yesNo ) {
                [self testConnectionAndFinish];
            }
        }];
    }
    else {
        [self testConnectionAndFinish];
    }
}

- (void)updateDraftConfiguration { 
    if ( self.draftConfiguration == nil ) {
        self.draftConfiguration = [[SFTPSessionConfiguration alloc] init];
    }
    
    if ( self.initialConfiguration ) {
        self.draftConfiguration.identifier = self.initialConfiguration.identifier;
    }
    
    NSString* name = trim(self.textFieldName.stringValue);
    self.draftConfiguration.name = name;
    
    NSString* host = [self.textFieldHost.stringValue stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    
    self.draftConfiguration.host = host;
    self.draftConfiguration.username = self.textFieldUsername.stringValue;
    self.draftConfiguration.password = self.textFieldPassword.stringValue;
    self.draftConfiguration.authenticationMode = (self.buttonPrivateKey.state == NSControlStateValueOn) ? kPrivateKey : kUsernamePassword;
    self.draftConfiguration.privateKey = self.privateKey;
    self.draftConfiguration.initialDirectory = self.textFieldPath.stringValue;
}

- (void)testConnectionAndFinish {
    [self updateDraftConfiguration];
    
    if ( [self.initialConfiguration isNetworkingFieldsAreSame:self.draftConfiguration] ) {
        [self.presentingViewController dismissViewController:self];
        self.onDone(YES, self.draftConfiguration);
    }
    else {
        [SFTPStorageProvider.sharedInstance testConnection:self.draftConfiguration
                                            viewController:self
                                                completion:^(NSError * _Nonnull error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if ( error ) {
                    [MacAlerts error:error window:self.view.window];
                }
                else {
                    [self.presentingViewController dismissViewController:self];
                    self.onDone(YES, self.draftConfiguration);
                }
            });
        }];
    }
}

- (IBAction)onCancel:(id)sender {
    [self.presentingViewController dismissViewController:self]; 
    self.onDone(NO, nil);
}

@end
