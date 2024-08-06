//
//  SFTPSessionConfigurationViewController.m
//  Strongbox-iOS
//
//  Created by Mark on 12/12/2018.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import "SFTPSessionConfigurationViewController.h"
#import <MobileCoreServices/MobileCoreServices.h>
#import "Alerts.h"
#import "Utils.h"
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>

#ifndef NO_NETWORKING
#import "SFTPStorageProvider.h"
#endif

@interface SFTPSessionConfigurationViewController () <UIDocumentPickerDelegate>

@property (weak, nonatomic) IBOutlet UITextField *textFieldHost;
@property (weak, nonatomic) IBOutlet UITextField *textFieldUsername;
@property (weak, nonatomic) IBOutlet UITextField *textFieldPassword;
@property (weak, nonatomic) IBOutlet UISwitch *switchUsePrivateKey;
@property (weak, nonatomic) IBOutlet UIButton *buttonLocateKey;
@property (weak, nonatomic) IBOutlet UIButton *buttonConnect;
@property (weak, nonatomic) IBOutlet UILabel *labelValidation;
@property (weak, nonatomic) IBOutlet UITextField *textFieldPath;
@property (weak, nonatomic) IBOutlet UITextField *textFieldName;

@property NSString* privateKey;

@end

@implementation SFTPSessionConfigurationViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    self.switchUsePrivateKey.on = NO;

    if ( self.initialConfiguration ) {
        self.textFieldName.text = self.initialConfiguration.name ? self.initialConfiguration.name : @"";
        self.textFieldHost.text = self.initialConfiguration.host;
        self.textFieldUsername.text = self.initialConfiguration.username;
        self.textFieldPassword.text = self.initialConfiguration.password;
        self.switchUsePrivateKey.on = self.initialConfiguration.authenticationMode == kPrivateKey;
        self.textFieldPath.text = self.initialConfiguration.initialDirectory;
        
        self.privateKey = self.initialConfiguration.privateKey;
    }
    else {
        [self.textFieldName becomeFirstResponder];
    }
    
    [self bindUi];
}

- (IBAction)onTextFieldChanged:(id)sender {
    [self bindUi];
}

- (IBAction)onCancel:(id)sender {
    self.onDone(NO, nil);
}

- (IBAction)onConnect:(id)sender {
    NSString* path = self.textFieldPath.text;
    if (path.pathExtension.length != 0) {
        [Alerts yesNo:self
                title:NSLocalizedString(@"sftp_path_may_be_invalid", @"Path may be Invalid")
              message:NSLocalizedString(@"sftp_path_are_you_sure", @"Are you sure the path is correct? It should be a path to a parent folder. Not the database file.")
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
    SFTPSessionConfiguration* configuration = [[SFTPSessionConfiguration alloc] init];
    
    NSString* name = trim(self.textFieldName.text);
    NSString* host = [self.textFieldHost.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];

    if ( self.initialConfiguration ) {
        configuration.identifier = self.initialConfiguration.identifier;
    }
    
    configuration.name = name;
    configuration.host = host;
    configuration.username = self.textFieldUsername.text;
    configuration.password = self.textFieldPassword.text;
    configuration.authenticationMode = self.switchUsePrivateKey.on ? kPrivateKey : kUsernamePassword;
    configuration.privateKey = self.privateKey;
    configuration.initialDirectory = self.textFieldPath.text;
    
#ifndef NO_NETWORKING
    [SFTPStorageProvider.sharedInstance testConnection:configuration viewController:self completion:^(NSError * _Nonnull error) {
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

- (IBAction)onUsePrivateKey:(id)sender {
    [self bindUi];
}

- (void)bindUi {
    self.buttonLocateKey.enabled = self.switchUsePrivateKey.on;
    [self validateConnect];
}

- (void)validateConnect {
    BOOL ok;
    
    NSString* name = trim(self.textFieldName.text);
    NSString* host = [self.textFieldHost.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    NSString* path = self.textFieldPath.text;

    if ( name.length == 0 ) {
        self.labelValidation.text = NSLocalizedString(@"connection_vc_name_invalid", @"Please enter a valid name.");
        self.labelValidation.textColor = [UIColor systemRedColor];
        ok = NO;
    }
    else if( !host.length ) {
        self.labelValidation.text = NSLocalizedString(@"sftp_vc_label_validation_enter_host", @"Please Enter a Host");
        self.labelValidation.textColor = [UIColor systemRedColor];
        ok = NO;
    }
    else if(self.switchUsePrivateKey.on && self.privateKey.length == 0) {
        self.labelValidation.text = NSLocalizedString(@"sftp_vc_label_validation_select_private_key", @"Select a Private Key...");
        self.labelValidation.textColor = [UIColor systemRedColor];
        ok = NO;
    }
    else if (path.pathExtension.length != 0) {
        self.labelValidation.text = NSLocalizedString(@"sftp_path_are_you_sure", @"Are you sure the path is correct? It should be a path to a parent folder. Not the database file.");
        self.labelValidation.textColor = [UIColor systemOrangeColor];
        ok = YES;
    }
    else {
        self.labelValidation.text = @"";
        ok = YES;
    }
    
    self.buttonConnect.enabled = ok;
}

- (IBAction)onLocateKey:(id)sender {
    UTType* type = [UTType typeWithIdentifier:(NSString*)kUTTypeItem];
    UIDocumentPickerViewController *vc = [[UIDocumentPickerViewController alloc] initForOpeningContentTypes:@[type]];
    

    vc.delegate = self;
    
    [self presentViewController:vc animated:YES completion:nil];
}

- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls {
    slog(@"didPickDocumentsAtURLs: %@", urls);
    
    NSURL* url = [urls objectAtIndex:0];
    
    
    
    if (! [url startAccessingSecurityScopedResource] ) {
        slog(@"🔴 Could not securely access URL!");
    }
    
    NSError* error;
    __block NSData *data;
    __block NSError *err;
    NSFileCoordinator *coordinator = [[NSFileCoordinator alloc] init];
    [coordinator coordinateReadingItemAtURL:url options:0 error:&error byAccessor:^(NSURL *newURL) {
        data = [NSData dataWithContentsOfURL:newURL options:NSDataReadingUncached error:&err];
    }];
    
    [url stopAccessingSecurityScopedResource];
    
    NSString* privateKey = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];

    if ( data != nil && privateKey != nil ) {
        self.privateKey = privateKey;
        [self.buttonLocateKey setTitle:[url lastPathComponent] forState:UIControlStateNormal];
    }
    else {
        [Alerts warn:self
               title:NSLocalizedString(@"sftp_vc_warn_invalid_key_title", @"Invalid Key")
             message:NSLocalizedString(@"sftp_vc_warn_invalid_key_message", @"This does not look like a valid private key")];
    }
    
    [self bindUi];
}

@end
