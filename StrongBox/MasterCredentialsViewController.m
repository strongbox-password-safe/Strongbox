//
//  MasterCredentialsViewController.m
//  Strongbox
//
//  Created by Mark on 28/05/2019.
//  Copyright © 2019 Mark McGuill. All rights reserved.
//

#import "MasterCredentialsViewController.h"
#import "Settings.h"
#import "Utils.h"
#import "Alerts.h"
#import "KeyFilesTableViewController.h"
#import "IOsUtils.h"

@interface MasterCredentialsViewController () <UITextFieldDelegate>

@property (weak, nonatomic) IBOutlet UILabel *labelMasterPassword;
@property (weak, nonatomic) IBOutlet UITextField *textFieldPassword;
@property (weak, nonatomic) IBOutlet UIButton *buttonKeyFile;
@property (weak, nonatomic) IBOutlet UISwitch *switchReadOnly;
@property (weak, nonatomic) IBOutlet UIButton *buttonUnlockOrSet;
@property (weak, nonatomic) IBOutlet UIStackView *stackView;
@property (weak, nonatomic) IBOutlet UILabel *labelKeyFile;
@property (weak, nonatomic) IBOutlet UIScrollView *scrollView;
@property (weak, nonatomic) IBOutlet UIView *containerView;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *barButtonUnlockOrSet;
@property (weak, nonatomic) IBOutlet UILabel *dummySpacerPreIOS11;
@property (weak, nonatomic) IBOutlet UISwitch *switchOpenOfflineCache;
@property (weak, nonatomic) IBOutlet UIView *openOfflineRow;
@property (weak, nonatomic) IBOutlet UIView *openReadOnlyOption;
@property (weak, nonatomic) IBOutlet UIButton *buttonShowHideAdvanced;
@property (weak, nonatomic) IBOutlet UIButton *buttonChevron;
@property (weak, nonatomic) IBOutlet UIView *advancedOptionsRow;
@property (weak, nonatomic) IBOutlet UILabel *labelOfflineCache;
@property (weak, nonatomic) IBOutlet UILabel *keyFileTip;
@property (weak, nonatomic) IBOutlet UIView *keyFileInfoRow;

@property NSData* oneTimeKeyFileData;
@property NSURL* selectedKeyFileUrl;

@end

@implementation MasterCredentialsViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [self setupUi];
}

- (IBAction)onShowHideAdvanced:(id)sender {
    Settings.sharedInstance.showAdvancedUnlockOptions = !Settings.sharedInstance.showAdvancedUnlockOptions;
    
    [self showHideAdvanced];
}

- (void)showHideAdvanced {
    [self.buttonChevron setTransform:CGAffineTransformMakeRotation(!Settings.sharedInstance.showAdvancedUnlockOptions ? 0.0 : M_PI / 2)];

    self.keyFileInfoRow.hidden = !Settings.sharedInstance.showAdvancedUnlockOptions;
    self.keyFileTip.hidden = YES;
    
    self.buttonKeyFile.hidden = !Settings.sharedInstance.showAdvancedUnlockOptions;
    self.openReadOnlyOption.hidden = !Settings.sharedInstance.showAdvancedUnlockOptions;
    self.openOfflineRow.hidden = !Settings.sharedInstance.showAdvancedUnlockOptions || !(self.database.offlineCacheEnabled && self.database.offlineCacheAvailable);

    if (self.database.offlineCacheEnabled && self.database.offlineCacheAvailable) {
        NSDate* modDate = [[LocalDeviceStorageProvider sharedInstance] getOfflineCacheFileModificationDate:self.database];
        self.labelOfflineCache.text = [NSString stringWithFormat:@"Open Offline Cache (%@)", modDate ? friendlyDateStringVeryShort(modDate) : @"Unknown"];
    }
    
    [self resizePreferredContentSize];
}

- (IBAction)onReadOnly:(id)sender {
    self.database.readOnly = self.switchReadOnly.on;
    [SafesList.sharedInstance update:self.database];
}

- (void)resizePreferredContentSize {
    CGFloat oldHeight = self.stackView.frame.size.height;
    
    [self.stackView setNeedsLayout];
    [self.stackView layoutIfNeeded];
    
    CGFloat diff = oldHeight - self.stackView.frame.size.height;
    
    [self setPreferredContentSize:CGSizeMake(self.preferredContentSize.width, self.preferredContentSize.height - diff)];
    
    [self.navigationController.presentationController.containerView setNeedsLayout];
    [self.navigationController.presentationController.containerView layoutIfNeeded];
}

- (void)setupUi {
    self.textFieldPassword.delegate = self;
    [self addShowHideToTextField:self.textFieldPassword];
    
    [self.textFieldPassword addTarget:self
                  action:@selector(validateUnlockOrSet)
        forControlEvents:UIControlEventEditingChanged];
    
    [self validateUnlockOrSet];
    
    self.textFieldPassword.enablesReturnKeyAutomatically = !Settings.sharedInstance.allowEmptyOrNoPasswordEntry;
    [self.buttonUnlockOrSet setTitleColor:UIColor.lightGrayColor forState:UIControlStateDisabled];

    NSString* keyFileButtonTitle = @"Select...";
    if(self.database.keyFileUrl) {
        NSLog(@"Configured: %@", self.database.keyFileUrl.path);
        
        if ([NSFileManager.defaultManager fileExistsAtPath:self.database.keyFileUrl.path]) {
            self.selectedKeyFileUrl = self.database.keyFileUrl;
            keyFileButtonTitle = Settings.sharedInstance.hideKeyFileOnUnlock ? @"(Configured)" : self.database.keyFileUrl.lastPathComponent;
        }
        else {
            keyFileButtonTitle = [NSString stringWithFormat:@"Select... (Configured not available)"];
        }
    }
    else {
        if(!Settings.sharedInstance.doNotAutoDetectKeyFiles) {
            NSURL* autoDetectedKeyFileUrl = [self getAutoDetectedKeyFileUrl];
            if(autoDetectedKeyFileUrl) {
                self.selectedKeyFileUrl  = autoDetectedKeyFileUrl;
                
                keyFileButtonTitle = Settings.sharedInstance.hideKeyFileOnUnlock ? @"(Auto Detected)" : [NSString stringWithFormat:@"%@ (Auto-Detected)", autoDetectedKeyFileUrl.lastPathComponent];
            }
        }
    }
    
    [self.buttonKeyFile setTitle:keyFileButtonTitle forState:UIControlStateNormal];

    // Checkbox Defaults
    
    self.switchReadOnly.on = self.database.readOnly;
    
    // Sizing
    
    self.keyFileTip.hidden = YES;
    
    if (@available(iOS 11.0, *)) {
        [self.stackView setCustomSpacing:4 afterView:self.labelMasterPassword];
        [self.stackView setCustomSpacing:8 afterView:self.advancedOptionsRow];
        [self.stackView setCustomSpacing:8 afterView:self.keyFileInfoRow];
    
        self.dummySpacerPreIOS11.hidden = YES;
    } else {
        self.dummySpacerPreIOS11.hidden = NO;
    }
    
    // Show Hide Elements
    
    [self showHideAdvanced];
    
    // iPad Modal Form Sheet Sizing Logic
    
    [self resizePreferredContentSize];
    
    // Finally Initialize Password Field with Focus
    
    [self.textFieldPassword becomeFirstResponder];
}

- (void)addShowHideToTextField:(UITextField*)textField {
    // Create button
    UIButton *checkbox = [UIButton buttonWithType:UIButtonTypeCustom];
    [checkbox setFrame:CGRectMake(2 , 2, 24, 24)];  // Not sure about size
    [checkbox setTag:1];
    [checkbox addTarget:self action:@selector(toggleShowHidePasswordText:) forControlEvents:UIControlEventTouchUpInside];
    
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
    [textField setTag:-1];
    textField.secureTextEntry = YES;
}

- (void)toggleShowHidePasswordText:(UIButton*)sender {
    if(sender.selected){
        [sender setSelected:FALSE];
    } else {
        [sender setSelected:TRUE];
    }
    
    self.textFieldPassword.secureTextEntry = !sender.selected;
}

- (BOOL)canSubmitPassword {
    return self.textFieldPassword.text.length > 0 || Settings.sharedInstance.allowEmptyOrNoPasswordEntry;
}

- (void)validateUnlockOrSet {
    self.buttonUnlockOrSet.enabled = [self canSubmitPassword];
    self.barButtonUnlockOrSet.enabled = [self canSubmitPassword];
    [self.buttonUnlockOrSet setTintColor:[self canSubmitPassword] ? nil : UIColor.lightGrayColor];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    if (textField == self.textFieldPassword) {
        if([self canSubmitPassword]) {
            [textField resignFirstResponder];
            [self onUnlockOrSet:nil];
        }
    }
    
    return YES;
}

- (IBAction)onCancel:(id)sender {
    if(self.onDone) {
        self.onDone(NO, nil, nil, NO);
    }
}

- (IBAction)onKeyFileTip:(id)sender {
    self.keyFileTip.hidden = !self.keyFileTip.hidden;
    
    [self.keyFileTip setNeedsLayout];
    [self.keyFileTip layoutIfNeeded];
    
    [self resizePreferredContentSize];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Key Files

- (IBAction)askForKeyFile:(id)sender {
    [self performSegueWithIdentifier:@"segueToKeyFiles" sender:nil];
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([segue.identifier isEqualToString:@"segueToKeyFiles"]) {
        UINavigationController *nav = segue.destinationViewController;
        KeyFilesTableViewController* vc = (KeyFilesTableViewController*)nav.topViewController;
        vc.selectedUrl = Settings.sharedInstance.hideKeyFileOnUnlock ? nil : self.selectedKeyFileUrl;
        
        vc.onDone = ^(BOOL success, NSURL * _Nullable url, NSData * _Nullable oneTimeData) {
            [self dismissViewControllerAnimated:YES completion:^{
                if(success) {
                    [self onKeyFileSelected:url oneTimeData:oneTimeData];
                }
            }];
        };
    }
}

- (void)onKeyFileSelected:(NSURL* _Nullable)url oneTimeData:(NSData * _Nullable)oneTimeData {
    if(url == nil && oneTimeData == nil) {
        self.oneTimeKeyFileData = nil;
        self.selectedKeyFileUrl = nil;
        [self.buttonKeyFile setTitle:@"Select..." forState:UIControlStateNormal];
    }
    else if(oneTimeData) {
        self.oneTimeKeyFileData = oneTimeData;
        self.selectedKeyFileUrl = nil;
        [self.buttonKeyFile setTitle:@"Key File Selected (Once-Off)" forState:UIControlStateNormal];
    }
    else {
        self.oneTimeKeyFileData = nil;
        self.selectedKeyFileUrl = url;
        [self.buttonKeyFile setTitle:[NSString stringWithFormat:@"%@", url.lastPathComponent] forState:UIControlStateNormal];
    }
    
    self.database.keyFileUrl = url;
    [SafesList.sharedInstance update:self.database];
}

- (NSString*)getExpectedAssociatedLocalKeyFileName:(NSString*)filename {
    NSString* veryLastFilename = [filename lastPathComponent];
    NSString* filenameOnly = [veryLastFilename stringByDeletingPathExtension];
    NSString* expectedKeyFileName = [filenameOnly stringByAppendingPathExtension:@"key"];
    
    return  expectedKeyFileName;
}

- (NSURL*)getAutoDetectedKeyFileUrl {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSURL *directory = [IOsUtils applicationDocumentsDirectory];
    NSError* error;
    
    NSString* expectedKeyFileName = [self getExpectedAssociatedLocalKeyFileName:self.database.fileName];

    NSArray<NSString*>* files = [fm contentsOfDirectoryAtPath:directory.path error:&error];
    
    if(!files) {
        NSLog(@"Error looking for auto detected key file url: %@", error);
        return nil;
    }
    
    for (NSString *file in files) {
        if([file caseInsensitiveCompare:expectedKeyFileName] == NSOrderedSame) {
            return [directory URLByAppendingPathComponent:file];
        }
    }
    
    return nil;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (IBAction)onUnlockOrSet:(id)sender {
    BOOL openOfflineCache = self.switchOpenOfflineCache.on && self.database.offlineCacheEnabled && self.database.offlineCacheAvailable;

    if(self.oneTimeKeyFileData) {
        self.onDone(YES, self.textFieldPassword.text, self.oneTimeKeyFileData, openOfflineCache);
    }
    else {
        if(self.selectedKeyFileUrl) {
            NSError* error;
            NSData* data = [NSData dataWithContentsOfURL:self.selectedKeyFileUrl options:kNilOptions error:&error];
            
            if(!data) {
                [Alerts error:self title:@"Error Reading Key File" error:error];
            }
            else {
                self.onDone(YES, self.textFieldPassword.text, data, openOfflineCache);
            }
        }
        else {
            self.onDone(YES, self.textFieldPassword.text, nil, openOfflineCache);
        }
    }
}

@end
