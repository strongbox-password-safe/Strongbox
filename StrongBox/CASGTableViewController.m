//
//  SetCredentialsTableViewController.m
//  Strongbox-iOS
//
//  Created by Mark on 31/05/2019.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import "CASGTableViewController.h"
#import "SelectDatabaseFormatTableViewController.h"
#import "KeyFilesTableViewController.h"
#import "IOsUtils.h"
#import "DatabasePreferences.h"
#import "Utils.h"
#import "Alerts.h"
#import "YubiKeyConfigurationController.h"
#import "YubiManager.h"
#import "AppPreferences.h"
#import "BookmarksHelper.h"
#import "VirtualYubiKeys.h"
#import "FontManager.h"
#import "PasswordStrengthTester.h"
#import "PasswordStrengthUIHelper.h"

@interface CASGTableViewController () <UITextFieldDelegate, UIAdaptivePresentationControllerDelegate>

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
@property (weak, nonatomic) IBOutlet UISwitch *switchReadOnly;
@property (weak, nonatomic) IBOutlet UITableViewCell *cellYubiKey;

@property (weak, nonatomic) IBOutlet UITableViewCell *cellRenameLocalFile;
@property (weak, nonatomic) IBOutlet UISwitch *switchRenameLocalFile;

@property (weak, nonatomic) IBOutlet UITableViewCell *cellAllowEmpty;
@property (weak, nonatomic) IBOutlet UISwitch *switchAllowEmpty;

@property (nullable) NSString* selectedName;
@property (nullable) NSString* selectedPassword;
@property (nullable) NSURL* selectedKeyFileUrl;
@property (nullable) NSData* selectedOneTimeKeyFileData;
@property (nullable) YubiKeyHardwareConfiguration* selectedYubiKeyConfig;

@property DatabaseFormat selectedFormat;
@property BOOL userHasChangedNameAtLeastOnce;

@property (weak, nonatomic) IBOutlet UITableViewCell *cellStrength;
@property (weak, nonatomic) IBOutlet UIProgressView *progressStrength;
@property (weak, nonatomic) IBOutlet UILabel *labelStrength;

@property (readonly) BOOL showStrength;
@property BOOL allowEmptyOrNoPasswordEntry; 
@end

@implementation CASGTableViewController

+ (instancetype)instantiateFromStoryboard {
    UIStoryboard* sb = [UIStoryboard storyboardWithName:@"CreateDatabaseOrSetCredentials" bundle:nil];
    
    UINavigationController* nav = [sb instantiateInitialViewController];
    
    CASGTableViewController* ret = (CASGTableViewController*)nav.topViewController;
    
    return ret;
}

- (void)viewDidLoad {
    [super viewDidLoad];
  
    self.allowEmptyOrNoPasswordEntry = AppPreferences.sharedInstance.allowEmptyOrNoPasswordEntry;
    
    self.navigationController.presentationController.delegate = self;
    [self setupUi];
    
    self.switchRenameLocalFile.on = YES;
    self.selectedName = self.initialName;
    self.selectedFormat = self.initialFormat;
    
    if ( self.initialKeyFileBookmark ) {
        NSURL* url = [BookmarksHelper getExpressReadOnlyUrlFromBookmark:self.initialKeyFileBookmark];
        self.selectedKeyFileUrl = url;
    }
    self.selectedYubiKeyConfig = self.initialYubiKeyConfig;
    
    self.switchReadOnly.on = self.initialReadOnly;
    
    if ( self.mode != kCASGModeSetCredentials && self.mode != kCASGModeGetCredentials) {
        self.textFieldName.text = self.selectedName.length ? self.selectedName : DatabasePreferences.suggestedNewDatabaseName;
    }
    
    self.textFieldPassword.font = FontManager.sharedInstance.easyReadFont;
    self.textFieldConfirmPassword.font = FontManager.sharedInstance.easyReadFont;
    
    [self bindUi];
}

- (void)setupUi {
    self.navigationItem.prompt = self.initialName ? self.initialName : nil;

    if(self.mode == kCASGModeCreate || self.mode == kCASGModeCreateExpress) {
        [self setTitle:NSLocalizedString(@"casg_create_database_action", @"Create Database")];
        [self.buttonDone setAccessibilityLabel:NSLocalizedString(@"casg_create_action", @"Create")];
        [self.buttonDone setTitle:NSLocalizedString(@"casg_create_action", @"Create")];
    }
    else if(self.mode == kCASGModeSetCredentials) {
        [self setTitle:self.initialFormat == kPasswordSafe ? NSLocalizedString(@"casg_set_master_password", @"Set Master Password") : NSLocalizedString(@"casg_set_master_credentials", @"Set Master Credentials")];
        [self.buttonDone setAccessibilityLabel:NSLocalizedString(@"generic_set", @"Set")];
        [self.buttonDone setTitle:NSLocalizedString(@"generic_set", @"Set")];
    }
    else if(self.mode == kCASGModeAddExisting) {
        [self setTitle:NSLocalizedString(@"casg_add_existing_database_action", @"Add Existing Database")];
        [self.buttonDone setAccessibilityLabel:NSLocalizedString(@"casg_add_action", @"Add")];
        [self.buttonDone setTitle:NSLocalizedString(@"casg_add_action", @"Add")];
    }
    else if(self.mode == kCASGModeGetCredentials) {
        [self setTitle:NSLocalizedString(@"casg_unlock_action", @"Unlock")];
        [self.buttonDone setTitle:NSLocalizedString(@"casg_unlock_action", @"Unlock")];
        [self.buttonDone setAccessibilityLabel:NSLocalizedString(@"casg_unlock_action", @"Unlock")];
    }
    else if(self.mode == kCASGModeRenameDatabase) {
        [self setTitle:NSLocalizedString(@"casg_rename_database_action", @"Rename Database")];
        [self.buttonDone setAccessibilityLabel:NSLocalizedString(@"casg_rename_action", @"Rename")];
        [self.buttonDone setTitle:NSLocalizedString(@"casg_rename_action", @"Rename")];
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
    self.textFieldPassword.enablesReturnKeyAutomatically = !self.allowEmptyOrNoPasswordEntry;
    

    
    self.textFieldConfirmPassword.delegate = self;
    
    self.textFieldName.delegate = self;
    self.textFieldName.enablesReturnKeyAutomatically = YES;
}

- (void)bindUi {
    [self bindAdvanced];
    [self bindFormat];
    [self bindKeyFile];
    [self bindYubiKey];
    [self bindPasswordFields];
    [self bindStrength];
    [self bindTableView]; 
    [self validateUi];
}

- (void)bindPasswordFields {
    [self addShowHideToTextField:self.textFieldPassword tag:1];
    [self addShowHideToTextField:self.textFieldConfirmPassword tag:2];
    
    self.textFieldPassword.placeholder =
        (self.mode == kCASGModeGetCredentials || self.allowEmptyOrNoPasswordEntry) ?
            NSLocalizedString(@"casg_text_field_placeholder_password", @"Password") :
            NSLocalizedString(@"casg_text_field_placeholder_password_required", @"Password (Required)");
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    if(self.mode == kCASGModeCreate || self.mode == kCASGModeCreateExpress) {
        [self.textFieldName becomeFirstResponder];
        [self.textFieldName selectAll:nil];
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

- (BOOL)yubiKeyIsSet {
    return self.selectedYubiKeyConfig != nil && self.selectedYubiKeyConfig.mode != kNoYubiKey;
}

- (BOOL)keyFileIsSet {
    return self.selectedOneTimeKeyFileData != nil || self.selectedKeyFileUrl != nil;
}

- (IBAction)onDone:(id)sender {
    if ( self.mode != kCASGModeSetCredentials && self.mode != kCASGModeGetCredentials) {
        self.selectedName = [DatabasePreferences trimDatabaseNickName:self.textFieldName.text];
    }
    
    self.selectedPassword = self.textFieldPassword.text;
    
    if(self.selectedPassword.length != 0 || self.mode == kCASGModeAddExisting || self.mode == kCASGModeRenameDatabase) {
        [self checkKeyFileForCommonMistake];
        return;
    }
    
    
    
    if(self.selectedFormat == kKeePass1 && [self keyFileIsSet]) {
        self.selectedPassword = nil; 
    }
    else if(([self keyFileIsSet]|| [self yubiKeyIsSet]) && (self.mode != kCASGModeGetCredentials)) {
        
        [self askAboutEmptyOrNonePasswordAndContinue];
        return;
    }

    [self checkKeyFileForCommonMistake];
}

- (void)askAboutEmptyOrNonePasswordAndContinue {
    [Alerts twoOptionsWithCancel:self
                           title:NSLocalizedString(@"casg_question_title_empty_password", @"Empty Password or None?")
                         message:NSLocalizedString(@"casg_question_message_empty_password", @"You have left the password field empty. This can be interpreted in two ways. Select the interpretation you want.")
               defaultButtonText:NSLocalizedString(@"casg_question_option_empty", @"Empty Password")
                secondButtonText:NSLocalizedString(@"casg_question_option_none", @"No Password")
                          action:^(int response) {
                              if(response == 0) {
                                  self.selectedPassword = @"";
                                  [self checkKeyFileForCommonMistake];
                              }
                              else if(response == 1) {
                                  self.selectedPassword = nil; 
                                  [self checkKeyFileForCommonMistake];
                              }
                          }];
}

- (void)checkKeyFileForCommonMistake {
    
    
    
    if ([self keyFileIsSet] && self.validateCommonKeyFileMistakes) {
        NSSet* commonDbExts = [NSSet setWithArray:@[@"kdbx", @"kdb", @"psafe3"]];
        BOOL likelyCommonMistake = [commonDbExts containsObject:self.selectedKeyFileUrl.pathExtension.lowercaseString];
        
        if(likelyCommonMistake) {
            NSString* title = NSLocalizedString(@"casg_key_file_correct_title", @"Is your Key File correct?");
            NSString* message = NSLocalizedString(@"casg_key_file_correct_message", @"You have configured this database to open with a Key File but the key file you have chosen doesn't look like a valid key file.\n\nAre you sure you are using this key file?\n\nNB: A Key File is not the same as your database file.");
            NSString* option1 = NSLocalizedString(@"casg_key_file_correct_yes_key_file_correct", @"Yes, the key file is correct");
            NSString* option2 = NSLocalizedString(@"casg_key_file_correct_no_no_key_file", @"No, I don't use a key file");
                                
            [Alerts twoOptionsWithCancel:self title:title message:message defaultButtonText:option1 secondButtonText:option2 action:^(int response) {
                slog(@"%d", response);
                
                if (response == 0) {
                    [self moveToDoneOrNext];
                }
                else if (response == 1) {
                    self.selectedKeyFileUrl = nil;
                    [self moveToDoneOrNext];
                }
            }];
        }
        else {
            [self moveToDoneOrNext];
        }
    }
    else {
        [self moveToDoneOrNext];
    }
}

- (void)moveToDoneOrNext {
    CASGParams* creds = [[CASGParams alloc] init];
    
    creds.name = self.selectedName;
    creds.password = self.selectedPassword;
    
    if (self.selectedKeyFileUrl) {
        NSError* error;
        NSString* bookmark = [BookmarksHelper getBookmarkFromUrl:self.selectedKeyFileUrl readOnly:YES error:&error];
        if (error) {
            slog(@"Error: Getting bookmark for Key File = [%@]", error);
            self.onDone(NO, nil);
            return;
        }
        else {
            creds.keyFileBookmark = bookmark;
            creds.keyFileFileName = self.selectedKeyFileUrl.lastPathComponent;
        }
    }
    
    creds.oneTimeKeyFileData = self.selectedOneTimeKeyFileData;
    creds.format = self.selectedFormat;
    creds.readOnly = self.switchReadOnly.on;
    creds.renameFileToMatch = self.switchRenameLocalFile.on && self.showFileRenameOption;
    creds.yubiKeyConfig = self.selectedYubiKeyConfig;
    
    self.onDone(YES, creds);
}

- (void)bindTableView {
    BOOL showAllowEmpty = (self.selectedFormat == kKeePass1 && [self keyFileIsSet]) ||
                                                                self.selectedFormat == kKeePass4 ||
                                                                self.selectedFormat == kKeePass ||
                                                                self.selectedFormat == kFormatUnknown;

    [self cell:self.cellStrength setHidden:!self.showStrength];
    
    if(self.mode == kCASGModeAddExisting || self.mode == kCASGModeRenameDatabase) {
        [self cell:self.cellKeyFile setHidden:YES];
        [self cell:self.cellYubiKey setHidden:YES];
        [self cell:self.cellFormat setHidden:YES];
        [self cell:self.cellPassword setHidden:YES];
        [self cell:self.cellConfirmPassword setHidden:YES];
        [self cell:self.cellReadOnly setHidden:YES];
        [self cell:self.cellAllowEmpty setHidden:YES];
        
        [self cell:self.cellRenameLocalFile setHidden:self.mode != kCASGModeRenameDatabase || !self.showFileRenameOption];
    }
    else if(self.mode == kCASGModeCreate || self.mode == kCASGModeCreateExpress) {
        [self cell:self.cellDatabaseName setHidden:!(self.mode == kCASGModeCreate || self.mode == kCASGModeCreateExpress)];
        [self cell:self.cellConfirmPassword setHidden:(self.mode == kCASGModeCreate || self.mode == kCASGModeCreateExpress)];
        [self cell:self.cellKeyFile setHidden:self.mode == kCASGModeCreateExpress || self.selectedFormat == kPasswordSafe];
        
        [self cell:self.cellYubiKey setHidden:self.mode == kCASGModeCreateExpress || ![self yubiKeyAvailable:self.selectedFormat]];
        
        [self cell:self.cellFormat setHidden:self.mode == kCASGModeCreateExpress];
        [self cell:self.cellReadOnly setHidden:YES];
        [self cell:self.cellRenameLocalFile setHidden:YES];
        
        [self cell:self.cellAllowEmpty setHidden:self.mode == kCASGModeCreateExpress || !showAllowEmpty];
    }
    else if(self.mode == kCASGModeSetCredentials) {
        [self cell:self.cellDatabaseName setHidden:YES];
        [self cell:self.cellFormat setHidden:YES];
        [self cell:self.cellKeyFile setHidden:self.initialFormat == kPasswordSafe];
        [self cell:self.cellYubiKey setHidden:![self yubiKeyAvailable:self.initialFormat]];
        [self cell:self.cellReadOnly setHidden:YES];
        [self cell:self.cellRenameLocalFile setHidden:YES];
        
        [self cell:self.cellAllowEmpty setHidden:!showAllowEmpty];
    }
    else if(self.mode == kCASGModeGetCredentials) {
        [self cell:self.cellAllowEmpty setHidden:!showAllowEmpty];
        [self cell:self.cellDatabaseName setHidden:YES];
        [self cell:self.cellFormat setHidden:YES];
        [self cell:self.cellConfirmPassword setHidden:YES];
        [self cell:self.cellKeyFile setHidden:self.initialFormat == kPasswordSafe];
        [self cell:self.cellYubiKey setHidden:![self yubiKeyAvailable:self.initialFormat]];
        [self cell:self.cellRenameLocalFile setHidden:YES];
    }
    
    if ( AppPreferences.sharedInstance.databasesAreAlwaysReadOnly ) {
        [self cell:self.cellReadOnly setHidden:YES];
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
        vc.selectedUrl = AppPreferences.sharedInstance.hideKeyFileOnUnlock ? nil : self.selectedKeyFileUrl;
        
        vc.onDone = ^(BOOL success, NSURL * _Nullable url, NSData * _Nullable oneTimeData) {
            if (success) {
                self.selectedKeyFileUrl = url;
                self.selectedOneTimeKeyFileData = oneTimeData;
                self.autoDetectedKeyFile = NO;
                [self bindUi];
            }
        };
    }
    else if ([segue.identifier isEqualToString:@"segueToYubiKeyConfiguration"]) {
        YubiKeyConfigurationController* vc = (YubiKeyConfigurationController*)segue.destinationViewController;
        
        vc.initialConfiguration = self.selectedYubiKeyConfig;
        vc.onDone = ^(YubiKeyHardwareConfiguration * _Nonnull config) {
            self.selectedYubiKeyConfig = config;
            [self bindUi];
        };
    }
}

- (void)bindKeyFile {
    if(self.selectedOneTimeKeyFileData) {
        self.cellKeyFile.textLabel.text = NSLocalizedString(@"casg_text_label_key_selected_key_file", @"Selected Key File");
        self.cellKeyFile.imageView.image = [UIImage imageNamed:@"key"];
        self.cellKeyFile.detailTextLabel.text = NSLocalizedString(@"casg_detail_label_one_off_key_file_selected", @"One Off");
        self.cellKeyFile.detailTextLabel.textColor = nil;
    }
    else if (self.selectedKeyFileUrl) {
        if ([NSFileManager.defaultManager fileExistsAtPath:self.selectedKeyFileUrl.path]) {
            self.cellKeyFile.imageView.image = [UIImage imageNamed:@"key"];
            
            if(AppPreferences.sharedInstance.hideKeyFileOnUnlock) {
                self.cellKeyFile.textLabel.text = self.autoDetectedKeyFile ?
                NSLocalizedString(@"casg_key_file_auto_detected", @"Auto-Detected") :
                NSLocalizedString(@"casg_key_file_configured", @"Configured");
                self.cellKeyFile.detailTextLabel.text = nil;
                self.cellKeyFile.detailTextLabel.textColor = nil;
            }
            else {
                self.cellKeyFile.textLabel.text = self.selectedKeyFileUrl.lastPathComponent;
                self.cellKeyFile.detailTextLabel.text = self.autoDetectedKeyFile ?
                NSLocalizedString(@"casg_key_file_auto_detected", @"Auto-Detected") :
                NSLocalizedString(@"casg_key_file_configured", @"Configured");
                self.cellKeyFile.detailTextLabel.textColor = nil;
            }
        }
        else {
            self.cellKeyFile.textLabel.text = NSLocalizedString(@"casg_key_file_select_action", @"Select...");
            self.cellKeyFile.detailTextLabel.text = NSLocalizedString(@"casg_key_file_configured_but_not_found", @"Configured Key File Not Found");
            self.cellKeyFile.detailTextLabel.textColor = UIColor.systemRedColor;
        }
    }
    else {
        self.cellKeyFile.textLabel.text = NSLocalizedString(@"casg_key_file_select_action", @"Select...");
        self.cellKeyFile.imageView.image = [UIImage imageNamed:@"key"];
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
            return NSLocalizedString(@"database_format_keepass1", @"KeePass 1");
            break;
        case kKeePass:
            return NSLocalizedString(@"database_format_keepass2_kdbx3_1", @"KeePass 2 (Legacy)");
            break;
        case kKeePass4:
            return NSLocalizedString(@"database_format_keepass2_kdbx4", @"KeePass 2");
            break;
        case kPasswordSafe:
            return NSLocalizedString(@"database_format_password_safe", @"Password Safe 3");
            break;
        default:
            return NSLocalizedString(@"generic_unknown", @"Unknown");
            break;
    }
}

- (NSString*)getFormatSubtitle:(DatabaseFormat)format {
    switch (format) {
        case kKeePass1:
            return NSLocalizedString(@"casg_database_format_information_kp1", @"KDB, AES (Supports Icons & Attachments)");
            break;
        case kKeePass:
            return NSLocalizedString(@"casg_database_format_information_kp31", @"KDBX 3.1, Salsa20 and AES (Most Compatible)");
            break;
        case kKeePass4:
            return NSLocalizedString(@"casg_database_format_information_kp4", @"KDBX 4.0, ChaCha20, Argon2D (GPU Brute Force Resistant)");
            break;
        case kPasswordSafe:
            return NSLocalizedString(@"casg_database_format_information_pwsafe", @"PSAFE3 version 3.x, TwoFish, SHA256");
            break;
        default:
            return NSLocalizedString(@"generic_unknown", @"Unknown");
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

- (void)textFieldNameDidChange:(id)sender {
    self.userHasChangedNameAtLeastOnce = YES;
    [self validateUi];
}

- (BOOL)showStrength {
    return self.mode != kCASGModeAddExisting && self.mode != kCASGModeRenameDatabase && self.mode != kCASGModeGetCredentials;
}

- (void)textFieldPasswordDidChange:(id)sender {
    [self validateUi];

    if ( self.showStrength ) {
        [self bindStrength];
    }
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
        if([self canSet]) {
            [textField resignFirstResponder];
            [self onDone:nil];
        }
    }

    return YES;
}

- (void)addShowHideToTextField:(UITextField*)textField tag:(NSInteger)tag {
    
    UIButton *checkbox = [UIButton buttonWithType:UIButtonTypeCustom];
    [checkbox setFrame:CGRectMake(2 , 2, 24, 24)];  
    [checkbox setTag:tag]; 
    
    [checkbox addTarget:self action:@selector(toggleShowHidePasswordText:) forControlEvents:UIControlEventTouchUpInside];
    
    [checkbox setAccessibilityLabel:NSLocalizedString(@"casg_accessibility_label_show_hide_pw", @"Show/Hide Password")];
    
    
    [checkbox.imageView setContentMode:UIViewContentModeScaleAspectFit];
    
    UIImage *concealed;
    UIImage *revealed;
    
    concealed = [UIImage systemImageNamed:@"eye"];
    revealed = [UIImage systemImageNamed:@"eye.slash"];

    [checkbox setImage:concealed forState:UIControlStateNormal];
    [checkbox setImage:revealed forState:UIControlStateSelected];
    [checkbox setImage:revealed forState:UIControlStateHighlighted];
    
    
    [textField setClearButtonMode:UITextFieldViewModeAlways];
    [textField setRightViewMode:UITextFieldViewModeAlways];
    [textField setRightView:checkbox];
    
    

    textField.secureTextEntry = YES;
}

- (void)toggleShowHidePasswordText:(UIButton*)sender {
    if ( sender.selected ){
        [sender setSelected:NO];
    } else {
        [sender setSelected:YES];
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

        [self.cellDatabaseName setTintColor:uiNameValid ? nil : UIColor.systemRedColor];
        self.cellDatabaseName.accessoryView = uiNameValid ? nil : [[UIImageView alloc] initWithImage: [UIImage imageNamed:@"cancel"]];

        self.buttonDone.enabled = [self canCreate];
    }
    else if(self.mode == kCASGModeAddExisting || self.mode == kCASGModeRenameDatabase) {
        BOOL uiNameValid = !self.userHasChangedNameAtLeastOnce || self.textFieldName.text.length == 0 || [self nameIsValid];
        
        [self.cellDatabaseName setTintColor:uiNameValid ? nil : UIColor.systemRedColor];
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
    BOOL formatAllowsEmptyOrNone =  self.initialFormat == kKeePass4 ||
                                    self.initialFormat == kKeePass ||
                                    self.initialFormat == kFormatUnknown ||
                                    (self.initialFormat == kKeePass1 && [self keyFileIsSet]);
    
    return (formatAllowsEmptyOrNone && self.allowEmptyOrNoPasswordEntry) || self.textFieldPassword.text.length;
}

- (BOOL)canSet {
    return ([self.textFieldPassword.text compare:self.textFieldConfirmPassword.text] == NSOrderedSame) && [self credentialsValidForDatabaseFormat];
}

- (BOOL)canCreate {
    return [self nameIsValid] && [self credentialsValidForDatabaseFormat];
}

- (BOOL)nameIsValid {
    NSString* sanitized = [DatabasePreferences trimDatabaseNickName:self.textFieldName.text];
    return [DatabasePreferences isValid:sanitized] && [DatabasePreferences isUnique:sanitized];
}

- (BOOL)passwordIsValid {
    BOOL formatAllowsEmptyOrNone = self.selectedFormat != kPasswordSafe;
    BOOL preferenceAllowsEmpty = self.allowEmptyOrNoPasswordEntry;
    
    return (preferenceAllowsEmpty && formatAllowsEmptyOrNone) ? YES : self.textFieldPassword.text.length > 0;
}

- (BOOL)credentialsValidForDatabaseFormat {
    if(self.selectedFormat == kKeePass1) {
        return [self passwordIsValid] && (self.textFieldPassword.text.length > 0 || [self keyFileIsSet]);
    }
    else {
        return [self passwordIsValid];
    }
}

- (IBAction)onAdvancedChanged:(id)sender {
    AppPreferences.sharedInstance.allowEmptyOrNoPasswordEntry = self.switchAllowEmpty.on;
    self.allowEmptyOrNoPasswordEntry = AppPreferences.sharedInstance.allowEmptyOrNoPasswordEntry;
    
    [self bindUi];
}

- (void)bindAdvanced {
    self.switchAllowEmpty.on = self.allowEmptyOrNoPasswordEntry;
}

- (void)bindYubiKey {
    if(self.selectedYubiKeyConfig != nil && self.selectedYubiKeyConfig.mode != kNoYubiKey) {
        if (self.selectedYubiKeyConfig.mode == kVirtual) {
            self.cellYubiKey.textLabel.text = NSLocalizedString(@"casg_yubikey_configured_virtual", @"Virtual");
            self.cellYubiKey.textLabel.textColor = nil;
            
            VirtualYubiKey* key = [VirtualYubiKeys.sharedInstance getById:self.selectedYubiKeyConfig.virtualKeyIdentifier];
            
            if (!key) {
                self.selectedYubiKeyConfig.mode = kNoYubiKey;
                self.selectedYubiKeyConfig.virtualKeyIdentifier = @"";
                
                self.cellYubiKey.textLabel.text = NSLocalizedString(@"casg_yubikey_configure_action", @"Configure...");
                self.cellYubiKey.imageView.image = [UIImage imageNamed:@"yubikey"];
                self.cellYubiKey.detailTextLabel.text = nil;
                self.cellYubiKey.detailTextLabel.textColor = nil;
            }
            else {
                self.cellYubiKey.detailTextLabel.text = key.name;
                self.cellYubiKey.detailTextLabel.textColor = nil;
            }
        }
        else {
            if (self.selectedYubiKeyConfig.mode == kMfi) {
                self.cellYubiKey.textLabel.text = AppPreferences.sharedInstance.isPro ?
                    NSLocalizedString(@"casg_yubikey_configured_mfi", @"Lightning") :
                    NSLocalizedString(@"casg_yubikey_configured_disabled_pro_only", @"Disabled (Pro Edition Only)");
                self.cellYubiKey.textLabel.textColor = AppPreferences.sharedInstance.isPro ? nil : UIColor.systemRedColor;
            }
            else {
                self.cellYubiKey.textLabel.text = AppPreferences.sharedInstance.isPro ?
                    NSLocalizedString(@"casg_yubikey_configured_nfc", @"NFC") :
                    NSLocalizedString(@"casg_yubikey_configured_disabled_pro_only", @"Disabled (Pro Edition Only)");
                self.cellYubiKey.textLabel.textColor = AppPreferences.sharedInstance.isPro ? nil : UIColor.systemRedColor;
            }
    
            self.cellYubiKey.detailTextLabel.text = self.selectedYubiKeyConfig.slot == kSlot1 ? NSLocalizedString(@"casg_yubikey_configured_slot1", @"Slot 1") :
                NSLocalizedString(@"casg_yubikey_configured_slot2", @"Slot 2");
            self.cellYubiKey.detailTextLabel.textColor = AppPreferences.sharedInstance.isPro ? nil : UIColor.systemRedColor;
        }
        
        self.cellYubiKey.imageView.image = [UIImage imageNamed:@"yubikey"];
    }
    else {
        self.cellYubiKey.textLabel.text = NSLocalizedString(@"casg_yubikey_configure_action", @"Configure...");
        self.cellYubiKey.imageView.image = [UIImage imageNamed:@"yubikey"];
        self.cellYubiKey.detailTextLabel.text = nil;
    }
}

- (BOOL)yubiKeyAvailable:(DatabaseFormat)format {
    return [self formatSupportsYubiKey:format];
}

- (BOOL)formatSupportsYubiKey:(DatabaseFormat)format {
    return format == kKeePass || format == kKeePass4;
}

- (void)bindStrength {
    [PasswordStrengthUIHelper bindStrengthUI:self.textFieldPassword.text
                                      config:AppPreferences.sharedInstance.passwordStrengthConfig
                          emptyPwHideSummary:YES
                                       label:self.labelStrength
                                    progress:self.progressStrength];
}

- (void)presentationControllerDidDismiss:(UIPresentationController *)presentationController {

    
    [self onCancel:nil];
}

@end
