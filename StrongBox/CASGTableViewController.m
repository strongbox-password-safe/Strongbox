//
//  SetCredentialsTableViewController.m
//  Strongbox-iOS
//
//  Created by Mark on 31/05/2019.
//  Copyright © 2019 Mark McGuill. All rights reserved.
//

#import "CASGTableViewController.h"
#import "SelectDatabaseFormatTableViewController.h"
#import "KeyFilesTableViewController.h"
#import "IOsUtils.h"
#import "SafesList.h"
#import "Utils.h"
#import "Settings.h"
#import "Alerts.h"

@interface CASGTableViewController () <UITextFieldDelegate>

@property (weak, nonatomic) IBOutlet UITableViewCell *cellDatabaseName;
@property (weak, nonatomic) IBOutlet UITableViewCell *cellKeyFile;
@property (weak, nonatomic) IBOutlet UITableViewCell *cellFormat;
@property (weak, nonatomic) IBOutlet UITextField *textFieldName;
@property (weak, nonatomic) IBOutlet UITextField *textFieldPassword;
@property (weak, nonatomic) IBOutlet UITextField *textFieldConfirmPassword;
@property (weak, nonatomic) IBOutlet UITableViewCell *cellConfirmPassword;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *buttonDone;
@property (weak, nonatomic) IBOutlet UITableViewCell *cellPassword;
@property (weak, nonatomic) IBOutlet UITableViewCell *cellReadOnly;
@property (weak, nonatomic) IBOutlet UITableViewCell *cellOpenOffline;
@property (weak, nonatomic) IBOutlet UISwitch *switchReadOnly;
@property (weak, nonatomic) IBOutlet UISwitch *switchOpenOffline;

@property (nullable) NSString* selectedName;
@property (nullable) NSString* selectedPassword;
@property (nullable) NSURL* selectedKeyFileUrl;
@property (nullable) NSData* selectedOneTimeKeyFileData;
@property DatabaseFormat selectedFormat;
@property (weak, nonatomic) IBOutlet UILabel *labelOfflineCache;

@property BOOL userHasChangedNameAtLeastOnce;

@end

@implementation CASGTableViewController

- (void)viewDidLoad {
    [super viewDidLoad];
  
    [self setupUi];
    
    self.selectedName = self.initialName;
    self.selectedFormat = self.initialFormat;
    self.selectedKeyFileUrl = self.initialKeyFileUrl;
    self.switchReadOnly.on = self.initialReadOnly;
    self.switchOpenOffline.on = self.initialOfflineCache;
    
    self.textFieldName.text = self.selectedName.length ? self.selectedName : [self getSuggestedDatabaseName];
    
    [self bindUi];
}

- (void)setupUi {
    if(self.mode == kCASGModeCreate || self.mode == kCASGModeCreateExpress) {
        [self  setTitle:@"Create Database"];
        [self.buttonDone setAccessibilityLabel:@"Create"];
        [self.buttonDone setTitle:@"Create"];
    }
    else if(self.mode == kCASGModeSetCredentials) {
        [self setTitle:self.initialFormat == kPasswordSafe ? @"Set Master Password" : @"Set Master Credentials"];
        [self.buttonDone setAccessibilityLabel:@"Set"];
        [self.buttonDone setTitle:@"Set"];
    }
    else if(self.mode == kCASGModeAddExisting) {
        [self setTitle:@"Add Existing Database"];
        [self.buttonDone setAccessibilityLabel:@"Add"];
        [self.buttonDone setTitle:@"Add"];
    }
    else if(self.mode == kCASGModeGetCredentials) {
        [self setTitle:@"Unlock"];
        [self.buttonDone setTitle:nil];
        [self.buttonDone setAccessibilityLabel:@"Unlock"];
        [self.buttonDone setImage:[UIImage imageNamed:@"unlock"]];
    }
    else if(self.mode == kCASGModeRenameDatabase) {
        [self setTitle:@"Rename Database"];
        [self.buttonDone setAccessibilityLabel:@"Rename"];
        [self.buttonDone setTitle:@"Rename"];
    }
    
    [self.textFieldName addTarget:self
                           action:@selector(textFieldNameDidChange:)
                 forControlEvents:UIControlEventEditingChanged];
    
    [self.textFieldPassword addTarget:self
                               action:@selector(textFieldPasswordDidChange:)
                     forControlEvents:UIControlEventEditingChanged];
    
    [self.textFieldConfirmPassword addTarget:self
                                      action:@selector(textFieldConfirmPasswordDidChange:)
                            forControlEvents:UIControlEventEditingChanged];
    
    self.textFieldPassword.delegate = self;
    self.textFieldPassword.enablesReturnKeyAutomatically = !Settings.sharedInstance.allowEmptyOrNoPasswordEntry;
    
    self.textFieldConfirmPassword.delegate = self;
    
    self.textFieldName.delegate = self;
    self.textFieldName.enablesReturnKeyAutomatically = YES;
}

- (void)bindUi {
    [self bindFormat];
    [self bindKeyFile];
    [self bindPasswordFields];
    [self bindTableView]; // Show / Hide Key File if password safe selected!
    [self validateUi];
}

- (void)bindPasswordFields {
    [self addShowHideToTextField:self.textFieldPassword tag:1];
    [self addShowHideToTextField:self.textFieldConfirmPassword tag:2];
    
    self.textFieldPassword.placeholder =
        (self.mode == kCASGModeGetCredentials || Settings.sharedInstance.allowEmptyOrNoPasswordEntry) ?
            @"Password" : @"Password (Required)";
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    if(self.mode == kCASGModeCreate || self.mode == kCASGModeCreateExpress) {
        if([self nameIsValid]) {
            [self.textFieldPassword becomeFirstResponder];
        }
        else {
            [self.textFieldName becomeFirstResponder];
        }
    }
    else if (self.mode == kCASGModeAddExisting || self.mode == kCASGModeRenameDatabase) {
        [self.textFieldName becomeFirstResponder];
        [self.textFieldName selectAll:nil];
    }
    else if (self.mode == kCASGModeSetCredentials || self.mode == kCASGModeGetCredentials) {
        [self.textFieldPassword becomeFirstResponder];
    }
}

- (IBAction)onCancel:(id)sender {
    self.onDone(NO, nil);
}

- (IBAction)onDone:(id)sender {
    self.selectedName = [SafesList sanitizeSafeNickName:self.textFieldName.text];
    self.selectedPassword = self.textFieldPassword.text;
    
    if(self.selectedPassword.length != 0 || self.mode == kCASGModeAddExisting || self.mode == kCASGModeRenameDatabase) {
        [self moveToDoneOrNext];
        return;
    }
    
    // Password is Empty... A few  different scenarios here, simplest case is get where we ask if the key file is set
    // otherwise it has to be @"" empty
    
    BOOL keyFileIsSet = self.selectedOneTimeKeyFileData != nil || self.selectedKeyFileUrl != nil;

    if(self.mode == kCASGModeGetCredentials) {
        if(keyFileIsSet) {
            [self askAboutEmptyOrNonePasswordAndContinue];
        }
        else {
            [self moveToDoneOrNext];
        }
        return;
    }
    
    // Second Case is the setting of the password and it depends on the format and whether the key file is set
    //
    // KeePass 1 and Password Safe don't allow empty:
    // Validation will prevent Password Safe from getting here
    // but KeePass1 allows none if using a key file.
    // If user enters empty and we are using KeePass1 with a keyFile set then count that as "None"...
    
    if(self.selectedFormat == kKeePass1 && keyFileIsSet) {
        self.selectedPassword = nil;
        [self moveToDoneOrNext];
    }
    else if (self.selectedFormat == kKeePass || self.selectedFormat == kKeePass4) {
        if(keyFileIsSet) {
            [self askAboutEmptyOrNonePasswordAndContinue];
        }
        else {
            self.selectedPassword = @"";
            [self moveToDoneOrNext];
        }
    }
}

- (void)askAboutEmptyOrNonePasswordAndContinue {
    [Alerts twoOptionsWithCancel:self
                           title:@"Empty Password or None?"
                         message:@"You have left the password field empty. This can be interpreted in two ways. Select the interpretation you want."
               defaultButtonText:@"Empty Password"
                secondButtonText:@"No Password"
                          action:^(int response) {
                              if(response == 0) {
                                  self.selectedPassword = @"";
                                  [self moveToDoneOrNext];
                              }
                              else if(response == 1) {
                                  self.selectedPassword = nil; // None
                                  [self moveToDoneOrNext];
                              }
                          }];
}

- (void)moveToDoneOrNext {
    CASGParams* creds = [[CASGParams alloc] init];
    
    creds.name = self.selectedName;
    creds.password = self.selectedPassword;
    creds.keyFileUrl = self.selectedKeyFileUrl;
    creds.oneTimeKeyFileData = self.selectedOneTimeKeyFileData;
    creds.format = self.selectedFormat;
    creds.readOnly = self.switchReadOnly.on;
    creds.offlineCache = self.switchOpenOffline.on;
    
    self.onDone(YES, creds);
}

- (void)bindTableView {
    if(self.mode == kCASGModeAddExisting || self.mode == kCASGModeRenameDatabase) {
        [self cell:self.cellKeyFile setHidden:YES];
        [self cell:self.cellFormat setHidden:YES];
        [self cell:self.cellPassword setHidden:YES];
        [self cell:self.cellConfirmPassword setHidden:YES];
        [self cell:self.cellReadOnly setHidden:YES];
        [self cell:self.cellOpenOffline setHidden:YES];
    }
    else if(self.mode == kCASGModeCreate || self.mode == kCASGModeCreateExpress) {
        [self cell:self.cellDatabaseName setHidden:!(self.mode == kCASGModeCreate || self.mode == kCASGModeCreateExpress)];
        [self cell:self.cellConfirmPassword setHidden:(self.mode == kCASGModeCreate || self.mode == kCASGModeCreateExpress)];
        [self cell:self.cellKeyFile setHidden:self.mode == kCASGModeCreateExpress || self.selectedFormat == kPasswordSafe];
        [self cell:self.cellFormat setHidden:self.mode == kCASGModeCreateExpress];
        [self cell:self.cellReadOnly setHidden:YES];
        [self cell:self.cellOpenOffline setHidden:YES];
    }
    else if(self.mode == kCASGModeSetCredentials) {
        [self cell:self.cellDatabaseName setHidden:YES];
        [self cell:self.cellFormat setHidden:YES];
        [self cell:self.cellKeyFile setHidden:self.initialFormat == kPasswordSafe];
        [self cell:self.cellReadOnly setHidden:YES];
        [self cell:self.cellOpenOffline setHidden:YES];
    }
    else if(self.mode == kCASGModeGetCredentials) {
        [self cell:self.cellDatabaseName setHidden:YES];
        [self cell:self.cellFormat setHidden:YES];
        [self cell:self.cellConfirmPassword setHidden:YES];
        [self cell:self.cellKeyFile setHidden:self.initialFormat == kPasswordSafe]; // This is sort of a hacky way to try hide the key file if we think the Database is probably Password Safe
        
        if(self.offlineCacheDate) {
            self.labelOfflineCache.text = [NSString stringWithFormat:@"Open Offline Cache (%@)",friendlyDateStringVeryShort(self.offlineCacheDate)];
        }
        else {
            [self cell:self.cellOpenOffline setHidden:YES];
        }
    }
    
    [self reloadDataAnimated:YES];
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if([segue.identifier isEqualToString:@"segueToSelectDatabaseFormat"]) {
        SelectDatabaseFormatTableViewController* vc = (SelectDatabaseFormatTableViewController*)segue.destinationViewController;
        vc.existingFormat = self.selectedFormat;
        vc.onSelectedFormat = ^(DatabaseFormat format) {
            self.selectedFormat = format;
            [self bindUi];
        };
    }
    else if ([segue.identifier isEqualToString:@"segueToSelectKeyFile"]) {
        KeyFilesTableViewController* vc = (KeyFilesTableViewController*)segue.destinationViewController;
        vc.selectedUrl = Settings.sharedInstance.hideKeyFileOnUnlock ? nil : self.selectedKeyFileUrl;
        
        vc.onDone = ^(BOOL success, NSURL * _Nullable url, NSData * _Nullable oneTimeData) {
            if (success) {
                self.selectedKeyFileUrl = url;
                self.selectedOneTimeKeyFileData = oneTimeData;
                self.autoDetectedKeyFileUrl = NO;
                [self bindUi];
            }
        };
    }
}

- (void)bindKeyFile {
    if(self.selectedOneTimeKeyFileData) {
        self.cellKeyFile.textLabel.text = @"Selected Key File";
        self.cellKeyFile.imageView.image = [UIImage imageNamed:@"key"];
        self.cellKeyFile.detailTextLabel.text = @"Once Off";
        self.cellKeyFile.detailTextLabel.textColor = nil;
    }
    else if (self.selectedKeyFileUrl) {
        if ([NSFileManager.defaultManager fileExistsAtPath:self.selectedKeyFileUrl.path]) {
            self.cellKeyFile.imageView.image = [UIImage imageNamed:@"key"];
            
            if(Settings.sharedInstance.hideKeyFileOnUnlock) {
                self.cellKeyFile.textLabel.text = self.autoDetectedKeyFileUrl ? @"Auto-Detected" : @"Configured";
                self.cellKeyFile.detailTextLabel.text = nil;
                self.cellKeyFile.detailTextLabel.textColor = nil;
            }
            else {
                self.cellKeyFile.textLabel.text = self.selectedKeyFileUrl.lastPathComponent;
                self.cellKeyFile.detailTextLabel.text = self.autoDetectedKeyFileUrl ? @"Auto-Detected" : @"Configured";
                self.cellKeyFile.detailTextLabel.textColor = nil;
            }
        }
        else {
            self.cellKeyFile.textLabel.text = @"Select...";
            self.cellKeyFile.detailTextLabel.text = @"Configured Key File Not Found";
            self.cellKeyFile.detailTextLabel.textColor = UIColor.redColor;
        }
    }
    else {
        self.cellKeyFile.textLabel.text = @"Select...";
        self.cellKeyFile.imageView.image = nil;
        self.cellKeyFile.detailTextLabel.text = nil;
    }
}

- (void)bindFormat {
    self.cellFormat.textLabel.text = [self getFormatTitle:self.selectedFormat];
    self.cellFormat.detailTextLabel.text = [self getFormatSubtitle:self.selectedFormat];
    self.cellFormat.imageView.image = [self getFormatImage:self.selectedFormat];
    [self resizeCellImage];
}

- (NSString*)getFormatTitle:(DatabaseFormat)format {
    switch (format) {
        case kKeePass1:
            return @"KeePass 1";
            break;
        case kKeePass:
            return @"KeePass 2 Classic";
            break;
        case kKeePass4:
            return @"KeePass 2 Advanced";
            break;
        case kPasswordSafe:
            return @"Password Safe 3";
            break;
        default:
            return @"Unknown!";
            break;
    }
}

- (NSString*)getFormatSubtitle:(DatabaseFormat)format {
    switch (format) {
        case kKeePass1:
            return @"KDB, AES (Supports Icons & Attachments)";
            break;
        case kKeePass:
            return @"KDBX 3.1, Salsa20 and AES (Most Compatible)";
            break;
        case kKeePass4:
            return @"KDBX 4.0, ChaCha20, Argon2D (GPU Brute Force Resistant)";
            break;
        case kPasswordSafe:
            return @"PSAFE3 version 3.x, TwoFish, SHA256";
            break;
        default:
            return @"Unknown!";
            break;
    }
}

- (UIImage*)getFormatImage:(DatabaseFormat)format {
    switch (format) {
        case kKeePass1:
        case kKeePass:
        case kKeePass4:
            return [UIImage imageNamed:@"keepass-icon-64x64"];
            break;
        case kPasswordSafe:
            return [UIImage imageNamed:@"pwsafe-icon-64x64"];
            break;
        default:
            return nil;
            break;
    }
}

- (void)resizeCellImage {
    CGSize itemSize = CGSizeMake(40, 40);
    
    UIGraphicsBeginImageContextWithOptions(itemSize, NO, UIScreen.mainScreen.scale);
    CGRect imageRect = CGRectMake(0.0, 0.0, itemSize.width, itemSize.height);
    [self.cellFormat.imageView.image drawInRect:imageRect];
    self.cellFormat.imageView.image = UIGraphicsGetImageFromCurrentImageContext();
    
    UIGraphicsEndImageContext();
}

- (NSString*)getSuggestedDatabaseName {
    NSString* name = [IOsUtils nameFromDeviceName];
    
    if(name.length > 0) {
        NSString *suggestion = [NSString stringWithFormat:@"%@'s Database", name];
        
        int attempt = 2;
        
        while(![[SafesList sharedInstance] isValidNickName:suggestion] && attempt < 50) {
            suggestion = [NSString stringWithFormat:@"%@'s Database %d", name, attempt++];
        }
        
        return [[SafesList sharedInstance] isValidNickName:suggestion] ? suggestion : nil;
    }
    
    return nil;
}

- (void)textFieldNameDidChange:(id)sender {
    self.userHasChangedNameAtLeastOnce = YES;
    [self validateUi];
}

- (void)textFieldPasswordDidChange:(id)sender {
    [self validateUi];
}

- (void)textFieldConfirmPasswordDidChange:(id)sender {
    [self validateUi];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    if(textField == self.textFieldPassword && (self.mode == kCASGModeCreate || self.mode == kCASGModeCreateExpress)) {
        if([self canCreate]) {
            [textField resignFirstResponder];
            [self onDone:nil];
        }
    }
    else if(textField == self.textFieldPassword && self.mode == kCASGModeGetCredentials) {
        if([self canGet]) {
            [textField resignFirstResponder];
            [self onDone:nil];
        }
    }
    else if((self.mode == kCASGModeAddExisting || self.mode == kCASGModeRenameDatabase) && textField == self.textFieldName) {
        if([self nameIsValid]) {
            [textField resignFirstResponder];
            [self onDone:nil];
        }
    }
    else if(self.mode == kCASGModeSetCredentials && (textField == self.textFieldPassword || textField == self.textFieldConfirmPassword)) {
        if([self credentialsValidForDatabaseFormat]) {
            [textField resignFirstResponder];
            [self onDone:nil];
        }
    }

    return YES;
}

- (void)addShowHideToTextField:(UITextField*)textField tag:(NSInteger)tag {
    // Create button
    UIButton *checkbox = [UIButton buttonWithType:UIButtonTypeCustom];
    [checkbox setFrame:CGRectMake(2 , 2, 24, 24)];  // Not sure about size
    [checkbox setTag:tag]; // hacky :(
    
    [checkbox addTarget:self action:@selector(toggleShowHidePasswordText:) forControlEvents:UIControlEventTouchUpInside];
    
    [checkbox setAccessibilityLabel:@"Show/Hide Password"];
    
    // Setup image for button
    [checkbox.imageView setContentMode:UIViewContentModeScaleAspectFit];
    [checkbox setImage:[UIImage imageNamed:@"visible"] forState:UIControlStateNormal];
    [checkbox setImage:[UIImage imageNamed:@"invisible"] forState:UIControlStateSelected];
    [checkbox setImage:[UIImage imageNamed:@"invisible"] forState:UIControlStateHighlighted];
    [checkbox setAdjustsImageWhenHighlighted:TRUE];
    checkbox.imageEdgeInsets = UIEdgeInsetsMake(0, -8, 0, 0); // Image is too close to border otherwise
                                                              //    checkbox.layer.borderColor = UIColor.redColor.CGColor;
                                                              //    checkbox.layer.borderWidth = 1;
    
    // Setup the right view in the text field
    [textField setClearButtonMode:UITextFieldViewModeAlways];
    [textField setRightViewMode:UITextFieldViewModeAlways];
    [textField setRightView:checkbox];
    
    // Setup Tag so the textfield can be identified
//    [textField setTag:-1];
    textField.secureTextEntry = YES;
}

- (void)toggleShowHidePasswordText:(UIButton*)sender {
    if(sender.selected){
        [sender setSelected:FALSE];
    } else {
        [sender setSelected:TRUE];
    }
    
    if(sender.tag == 1) {
        self.textFieldPassword.secureTextEntry = !sender.selected;
    }
    else {
        self.textFieldConfirmPassword.secureTextEntry = !sender.selected;
    }
}

- (void)validateUi {    
    if(self.mode == kCASGModeCreate || self.mode == kCASGModeCreateExpress) {
        BOOL uiNameValid = self.textFieldName.text.length == 0 || [self nameIsValid];

        [self.cellDatabaseName setTintColor:uiNameValid ? nil : UIColor.redColor];
        self.cellDatabaseName.accessoryView = uiNameValid ? nil : [[UIImageView alloc] initWithImage: [UIImage imageNamed:@"cancel"]];

        self.buttonDone.enabled = [self canCreate];
    }
    else if(self.mode == kCASGModeAddExisting || self.mode == kCASGModeRenameDatabase) {
        BOOL uiNameValid = !self.userHasChangedNameAtLeastOnce || self.textFieldName.text.length == 0 || [self nameIsValid];
        
        [self.cellDatabaseName setTintColor:uiNameValid ? nil : UIColor.redColor];
        self.cellDatabaseName.accessoryView = uiNameValid ? nil : [[UIImageView alloc] initWithImage: [UIImage imageNamed:@"cancel"]];

        self.buttonDone.enabled = [self nameIsValid];
    }
    else if(self.mode == kCASGModeSetCredentials) {
        self.buttonDone.enabled = [self canSet];
    }
    else if(self.mode == kCASGModeGetCredentials) {
        self.buttonDone.enabled = [self canGet];
    }
}

- (BOOL)canGet {
    return self.textFieldPassword.text.length || Settings.sharedInstance.allowEmptyOrNoPasswordEntry;
}

- (BOOL)canSet {
    return [self.textFieldPassword.text isEqualToString:self.textFieldConfirmPassword.text] && [self credentialsValidForDatabaseFormat];
}

- (BOOL)canCreate {
    return [self nameIsValid] && [self credentialsValidForDatabaseFormat];
}

- (BOOL)nameIsValid {
    return [SafesList.sharedInstance isValidNickName:trim(self.textFieldName.text)];
}

- (BOOL)passwordIsValid {
    BOOL formatAllowsEmptyOrNone = self.selectedFormat != kPasswordSafe;
    BOOL preferenceAllowsEmpty = Settings.sharedInstance.allowEmptyOrNoPasswordEntry;
    
    return (preferenceAllowsEmpty && formatAllowsEmptyOrNone) ? YES : self.textFieldPassword.text.length > 0;
}

- (BOOL)credentialsValidForDatabaseFormat {
    if(self.selectedFormat == kKeePass1) {
        BOOL keyFileIsSet = self.selectedOneTimeKeyFileData != nil || self.selectedKeyFileUrl != nil;
        return [self passwordIsValid] && (self.textFieldPassword.text.length > 0 || keyFileIsSet);
    }
    else {
        return [self passwordIsValid];
    }
}

// TODO: Might be nice to resize?
//- (void)resizePreferredContentSize {
//    CGFloat oldHeight = self.stackView.frame.size.height;
//
//    [self.stackView setNeedsLayout];
//    [self.stackView layoutIfNeeded];
//
//    CGFloat diff = oldHeight - self.stackView.frame.size.height;
//
//    [self setPreferredContentSize:CGSizeMake(self.preferredContentSize.width, self.preferredContentSize.height - diff)];
//
//    [self.navigationController.presentationController.containerView setNeedsLayout];
//    [self.navigationController.presentationController.containerView layoutIfNeeded];
//}

@end
