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
#import <MobileCoreServices/MobileCoreServices.h>

// TODO: do we need a way to clear the key file?    Not needed right now, but in phase 2 yeah I think

@interface MasterCredentialsViewController () <UITextFieldDelegate, UIDocumentPickerDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate>

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
@property NSData* keyFileData;
@property (weak, nonatomic) IBOutlet UILabel *keyFileTip;
@property (weak, nonatomic) IBOutlet UIView *keyFileInfoRow;

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

    // Key-File Auto Detected
    
    NSData* autoDetectedKeyFileDigest = [self findAssociatedLocalKeyFile:self.database.fileName];

    if(autoDetectedKeyFileDigest) {
        self.keyFileData = autoDetectedKeyFileDigest;
        [self.buttonKeyFile setTitle:[NSString stringWithFormat:@"Auto-Detected"] forState:UIControlStateNormal];
    }
    else {
        [self.buttonKeyFile setTitle:@"Select..." forState:UIControlStateNormal];
    }
    
    // Checkbox Defaults
    
    self.switchReadOnly.on = self.database.readOnly;
    
    // Sizing
    
    self.keyFileTip.hidden = YES;
    
    if (@available(iOS 11.0, *)) {
        [self.stackView setCustomSpacing:4 afterView:self.labelMasterPassword];
        [self.stackView setCustomSpacing:8 afterView:self.advancedOptionsRow];
        [self.stackView setCustomSpacing:4 afterView:self.keyFileInfoRow];
    
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

- (IBAction)onUnlockOrSet:(id)sender {
    if(self.onDone) {
        BOOL openOfflineCache = self.switchOpenOfflineCache.on && self.database.offlineCacheEnabled && self.database.offlineCacheAvailable;
        self.onDone(YES, self.textFieldPassword.text, self.keyFileData, openOfflineCache);
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
    [Alerts threeOptions:self
               title:@"Key File Source"
             message:@"Select where you would like to choose your Key File from"
   defaultButtonText:@"Files..."
    secondButtonText:@"Photo Library..."
     thirdButtonText:@"Cancel"
              action:^(int response) {
                  if(response == 0) {
                      UIDocumentPickerViewController *vc = [[UIDocumentPickerViewController alloc] initWithDocumentTypes:@[(NSString*)kUTTypeItem] inMode:UIDocumentPickerModeImport];
                      vc.delegate = self;
                      [self presentViewController:vc animated:YES completion:nil];
                  }
                  else if (response == 1) {
                      UIImagePickerController *vc = [[UIImagePickerController alloc] init];
                      vc.videoQuality = UIImagePickerControllerQualityTypeHigh;
                      vc.delegate = self;
                      BOOL available = [UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypeSavedPhotosAlbum];
                      
                      if(!available) {
                          [Alerts info:self
                                 title:@"Photo Library Unavailable"
                               message:@"Could not access Photo Library. Does Strongbox have Permission?"];
                          return;
                      }
                      
                      vc.mediaTypes = @[(NSString*)kUTTypeImage];
                      vc.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
                      
                      [self presentViewController:vc animated:YES completion:nil];
                  }
              }];
}

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary<UIImagePickerControllerInfoKey, id> *)info {
    [picker dismissViewControllerAnimated:YES completion:^{
        NSError* error;
        NSData* data = [Utils getImageDataFromPickedImage:info error:&error];
        
        if(!data) {
            NSLog(@"Error: %@", error);
            [Alerts error:self title:@"Error Reading Image" error:error];
        }
        else {
            NSLog(@"info = [%@]", info);
            
            self.keyFileData = data; 
            [self.buttonKeyFile setTitle:@"Selected Image" forState:UIControlStateNormal];
            
//            if (@available(iOS 11.0, *)) {
//                NSURL *url = info[UIImagePickerControllerImageURL];
//                self.textFieldKeyFile.text = url ? url.lastPathComponent : @"<Unknown Image File>";
//            } else {
//                NSURL *url = info[UIImagePickerControllerReferenceURL]; // Not sure if this is much use?
//                self.textFieldKeyFile.text = @"<Unknown Image File>";
//            }
        }
    }];
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker {
    [picker dismissViewControllerAnimated:YES completion:nil];
}

- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls {
    NSLog(@"didPickDocumentsAtURLs: %@", urls);
    
    NSURL* url = [urls objectAtIndex:0];
    NSString *filename = [url lastPathComponent];
    
    NSError* error;
    NSData* data = [NSData dataWithContentsOfURL:url options:kNilOptions error:&error];
    
    if(!data) {
        NSLog(@"Error: %@", error);
        [Alerts error:self title:@"There was an error reading the Key File" error:error completion:nil];
    }
    else {
        self.keyFileData = data;
        [self.buttonKeyFile setTitle:filename forState:UIControlStateNormal];
    }
}

- (NSString*)getExpectedAssociatedLocalKeyFileName:(NSString*)filename {
    NSString* veryLastFilename = [filename lastPathComponent];
    NSString* filenameOnly = [veryLastFilename stringByDeletingPathExtension];
    NSString* expectedKeyFileName = [filenameOnly stringByAppendingPathExtension:@"key"];
    
    return  expectedKeyFileName;
}

- (NSData*)findAssociatedLocalKeyFile:(NSString*)filename {
    if(Settings.sharedInstance.doNotAutoDetectKeyFiles) {
        return nil;
    }
    
    NSString* expectedKeyFileName = [self getExpectedAssociatedLocalKeyFileName:filename];
    
    NSLog(@"Looking for key file: [%@] in local documents directory:", expectedKeyFileName);
    
    NSData* fileData = [LocalDeviceStorageProvider.sharedInstance readWithCaseInsensitiveFilename:expectedKeyFileName];
    
    return fileData;
}


@end
