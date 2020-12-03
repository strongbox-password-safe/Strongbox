//
//  SFTPSessionConfigurationViewController.m
//  Strongbox-iOS
//
//  Created by Mark on 12/12/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
//

#import "SFTPSessionConfigurationViewController.h"
#import <MobileCoreServices/MobileCoreServices.h>
#import "Alerts.h"

@interface SFTPSessionConfigurationViewController () <UIDocumentPickerDelegate>

@property (weak, nonatomic) IBOutlet UITextField *textFieldHost;
@property (weak, nonatomic) IBOutlet UITextField *textFieldUsername;
@property (weak, nonatomic) IBOutlet UITextField *textFieldPassword;
@property (weak, nonatomic) IBOutlet UISwitch *switchUsePrivateKey;
@property (weak, nonatomic) IBOutlet UIButton *buttonLocateKey;
@property (weak, nonatomic) IBOutlet UIButton *buttonConnect;
@property (weak, nonatomic) IBOutlet UILabel *labelValidation;
@property (weak, nonatomic) IBOutlet UITextField *textFieldPath;

@property NSString* privateKey;

@end

@implementation SFTPSessionConfigurationViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    self.configuration = nil;
    self.switchUsePrivateKey.on = NO;
    
    [self bindUi];
    
    [self.textFieldHost becomeFirstResponder];
}

- (IBAction)onTextFieldChanged:(id)sender {
    [self bindUi];
}

- (IBAction)onCancel:(id)sender {
    self.configuration = nil;
    self.onDone(NO);
}

- (IBAction)onConnect:(id)sender {
    self.configuration = [[SFTPSessionConfiguration alloc] init];
    
    NSString* host = [self.textFieldHost.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    
    NSString* path = self.textFieldPath.text;
    if (path.pathExtension.length != 0) {
        [Alerts yesNo:self
                title:NSLocalizedString(@"sftp_path_may_be_invalid", @"Path may be Invalid")
              message:NSLocalizedString(@"sftp_path_are_you_sure", @"Are you sure the path is correct? It should be a path to a parent folder. Not the database file.")
               action:^(BOOL response) {
            if (response) {
                self.configuration.host = host;
                self.configuration.username = self.textFieldUsername.text;
                self.configuration.password = self.textFieldPassword.text;
                self.configuration.authenticationMode = self.switchUsePrivateKey.on ? kPrivateKey : kUsernamePassword;
                self.configuration.privateKey = self.privateKey;
                self.configuration.initialDirectory = self.textFieldPath.text;
                
                self.onDone(YES);
            }
        }];
    }
    else {
        self.configuration.host = host;
        self.configuration.username = self.textFieldUsername.text;
        self.configuration.password = self.textFieldPassword.text;
        self.configuration.authenticationMode = self.switchUsePrivateKey.on ? kPrivateKey : kUsernamePassword;
        self.configuration.privateKey = self.privateKey;
        self.configuration.initialDirectory = self.textFieldPath.text;
        
        self.onDone(YES);
    }
}

- (IBAction)onUsePrivateKey:(id)sender {
    [self bindUi];
}

- (void)bindUi {
    self.buttonLocateKey.enabled = self.switchUsePrivateKey.on;
    [self validateConnect];
}

- (void)validateConnect {
    NSString* host = [self.textFieldHost.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    
    if(!host.length) {
        self.labelValidation.text = NSLocalizedString(@"sftp_vc_label_validation_enter_host", @"Please Enter a Host");
        self.labelValidation.textColor = [UIColor systemRedColor];
        self.buttonConnect.enabled = NO;
        return;
    }
        
    if(self.switchUsePrivateKey.on && self.privateKey.length == 0) {
        self.labelValidation.text = NSLocalizedString(@"sftp_vc_label_validation_select_private_key", @"Select a Private Key...");
        self.labelValidation.textColor = [UIColor systemRedColor];
        self.buttonConnect.enabled = NO;
        return;
    }

    NSString* path = self.textFieldPath.text;
    if (path.pathExtension.length != 0) {
        self.labelValidation.text = NSLocalizedString(@"sftp_path_are_you_sure", @"Are you sure the path is correct? It should be a path to a parent folder. Not the database file.");
        self.labelValidation.textColor = [UIColor systemOrangeColor];
        self.buttonConnect.enabled = YES;
    }
    else {
        self.labelValidation.text = @"";
        self.buttonConnect.enabled = YES;
    }
    return;
}

- (IBAction)onLocateKey:(id)sender {
    UIDocumentPickerViewController *vc = [[UIDocumentPickerViewController alloc] initWithDocumentTypes:@[(NSString*)kUTTypeItem] inMode:UIDocumentPickerModeImport];
    vc.delegate = self;
    
    [self presentViewController:vc animated:YES completion:nil];
}

- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls {
    NSLog(@"didPickDocumentsAtURLs: %@", urls);
    
    NSURL* url = [urls objectAtIndex:0];

    #pragma GCC diagnostic push
    #pragma GCC diagnostic ignored "-Wdeprecated-declarations"
    [self documentPicker:controller didPickDocumentAtURL:url];
    #pragma GCC diagnostic pop
}

#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wdeprecated-implementations"
- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentAtURL:(NSURL *)url { 
    NSData* key = [NSData dataWithContentsOfURL:url];
    NSString* privateKey = [[NSString alloc] initWithData:key encoding:NSUTF8StringEncoding];

    if(privateKey != nil) {
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
#pragma GCC diagnostic pop

@end
