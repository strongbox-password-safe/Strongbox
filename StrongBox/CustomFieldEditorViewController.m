//
//  CustomFieldEditorControllerViewController.m
//  test-new-ui
//
//  Created by Mark on 23/04/2019.
//  Copyright © 2019 Mark McGuill. All rights reserved.
//

#import "CustomFieldEditorViewController.h"
#import "Utils.h"
#import "Entry.h"
#import "NSArray+Extensions.h"
#import "PasswordMaker.h"
#import "Settings.h"
#import "Alerts.h"

@interface CustomFieldEditorViewController () <UITextFieldDelegate, UITextViewDelegate>

@property (weak, nonatomic) IBOutlet UIScrollView *scrollView;
@property UIView* activeField;

@property (weak, nonatomic) IBOutlet UITextField *keyTextField;
@property (weak, nonatomic) IBOutlet UITextView *textView;
@property (weak, nonatomic) IBOutlet UISwitch *switchProtected;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *buttonDone;
@property (weak, nonatomic) IBOutlet UILabel *labelError;

@end

const static NSSet<NSString*> *keePassReservedNames;

@implementation CustomFieldEditorViewController

+ (void)initialize {
    if(self == [CustomFieldEditorViewController class]) {
        keePassReservedNames = [NSSet setWithArray:[[[Entry reservedCustomFieldKeys] allObjects] map:^id _Nonnull(NSString * _Nonnull obj, NSUInteger idx) {
            return obj.lowercaseString;
        }]];
    }
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    NSMutableSet *lowerCaseKeys = [NSMutableSet setWithCapacity:self.customFieldsKeySet.count];
    for (NSString* key in self.customFieldsKeySet.allObjects) {
        [lowerCaseKeys addObject:[key lowercaseString]];
    }
    self.customFieldsKeySet = lowerCaseKeys;
    
    self.textView.delegate = self;
    self.keyTextField.delegate = self;
    
    [self.keyTextField addTarget:self
                          action:@selector(textFieldDidChange:)
                forControlEvents:UIControlEventEditingChanged];
    
//    UIColor *borderColor = [UIColor colorWithRed:204.0/255.0 green:204.0/255.0 blue:204.0/255.0 alpha:1.0];
    
    if (@available(iOS 13.0, *)) {
        self.textView.layer.borderColor = UIColor.labelColor.CGColor;
    } else {
        UIColor *borderColor = [UIColor colorWithRed:204.0/255.0 green:204.0/255.0 blue:204.0/255.0 alpha:1.0];
        self.textView.layer.borderColor = borderColor.CGColor;
    }
    self.textView.layer.borderWidth = 0.5f;
    self.textView.layer.cornerRadius = 5.0f;

    [self registerForKeyboardNotifications];
    
    self.keyTextField.text = self.customField.key;
    self.textView.text = self.customField.value;
    self.switchProtected.on = self.customField.protected;

    self.keyTextField.accessibilityLabel = NSLocalizedString(@"custom_field_vc_accessibility_label_name", @"Custom Field Name");
    self.textView.accessibilityLabel = NSLocalizedString(@"custom_field_vc_accessibility_label_value", @"Custom Field Value");
    self.switchProtected.accessibilityLabel = NSLocalizedString(@"custom_field_vc_accessibility_label_protected", @"Custom Field Protected");
    
    [self.keyTextField becomeFirstResponder];
    
    [self validateUi];
}

- (void)registerForKeyboardNotifications
{
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWasShown:)
                                                 name:UIKeyboardDidShowNotification object:nil];
    
    
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWillBeHidden:)
                                                 name:UIKeyboardWillHideNotification object:nil];
}

- (void)validateUi {
    NSString* candidate = trim(self.keyTextField.text);
    NSString* error = @"";

    BOOL keyIsValid = candidate.length != 0;
    
    if(!keyIsValid) {
        error = NSLocalizedString(@"custom_field_vc_validation_name_not_empty_error", @"Name cannot be empty");
    }
    
    if(keyIsValid) {
        keyIsValid = ![keePassReservedNames containsObject:[candidate lowercaseString]];
        if(!keyIsValid) {
            error = NSLocalizedString(@"custom_field_vc_validation_name_not_reserved_error", @"Name cannot be one of the reserved KeePass Field names");
        }
    }
    
    if(keyIsValid) {
        if(self.customField) { // Existing Custom Field
            if(![candidate isEqualToString:self.customField.key]) { // Custom Field and they've changed the key
                NSMutableSet<NSString*> *otherKeys = [self.customFieldsKeySet mutableCopy];
                [otherKeys removeObject:self.customField.key];
                
                keyIsValid = ![otherKeys containsObject:[candidate lowercaseString]];
            }
        }
        else {
            keyIsValid = ![self.customFieldsKeySet containsObject:[candidate lowercaseString]];
        }
        
        if(!keyIsValid) {
            error = NSLocalizedString(@"custom_field_vc_validation_name_already_in_use_error", @"This key is already in use by another custom field.");
        }
    }
    
    if(!keyIsValid) {
        self.keyTextField.layer.borderColor = UIColor.systemRedColor.CGColor;
        self.keyTextField.layer.borderWidth = 0.5f;
        self.keyTextField.layer.cornerRadius = 5.0f;
        self.buttonDone.enabled = NO;
        self.labelError.text = error;
        self.labelError.hidden = NO;
    }
    else {
        if (@available(iOS 13.0, *)) {
            self.keyTextField.layer.borderColor = UIColor.labelColor.CGColor;
            self.keyTextField.layer.borderWidth = 0.5;
        } else {
            self.keyTextField.layer.borderColor = UIColor.systemRedColor.CGColor;
            self.keyTextField.layer.borderWidth = 0.0;
        }
        
        self.keyTextField.layer.cornerRadius = 5.0f;
        self.buttonDone.enabled = YES;
        self.labelError.text = @"";
        self.labelError.hidden = YES;
    }
}

- (void)keyboardWasShown:(NSNotification*)aNotification {
    NSDictionary* info = [aNotification userInfo];
    CGSize kbSize = [[info objectForKey:UIKeyboardFrameEndUserInfoKey] CGRectValue].size;
    
    UIEdgeInsets contentInsets = UIEdgeInsetsMake(0.0, 0.0, kbSize.height, 0.0);
    
    self.scrollView.contentInset = contentInsets;
    self.scrollView.scrollIndicatorInsets = contentInsets;
    
    // If active text field is hidden by keyboard, scroll it so it's visible
    // Your app might not need or want this behavior.
    
    CGRect aRect = self.view.frame;
    
    aRect.size.height -= kbSize.height;
    
    if (!CGRectContainsPoint(aRect, self.activeField.frame.origin) ) {
        [self.scrollView scrollRectToVisible:self.activeField.frame animated:YES];
    }
}

- (void)keyboardWillBeHidden:(NSNotification*)aNotification
{
    UIEdgeInsets contentInsets = UIEdgeInsetsZero;
    
    self.scrollView.contentInset = contentInsets;
    self.scrollView.scrollIndicatorInsets = contentInsets;
}

- (void)textFieldDidBeginEditing:(UITextField *)textField
{
    //NSLog(@"textFieldDidBeginEditing");
    self.activeField = textField;
}

- (void)textFieldDidEndEditing:(UITextField *)textField
{
//    NSLog(@"textFieldDidEndEditing");
    self.activeField = nil;
}

- (void)textViewDidBeginEditing:(UITextView *)textView {
//    NSLog(@"textViewDidBeginEditing");
    self.activeField = textView;
}

- (void)textViewDidEndEditing:(UITextView *)textView {
//    NSLog(@"textViewDidEndEditing");
    self.activeField = nil;
}

////////////////////////////////////////////////////////////////////////

- (IBAction)onDone:(id)sender {
    NSString* key = trim(self.keyTextField.text);
    NSString* value = [NSString stringWithString:self.textView.textStorage.string];
    BOOL protected = self.switchProtected.on;

    if(self.onDone) {
        self.onDone([CustomFieldViewModel customFieldWithKey:key value:value protected:protected]);
    }
    
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (IBAction)onCancel:(id)sender {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)textFieldDidChange:(id)sender {
    [self validateUi];
}

- (IBAction)onGenerate:(id)sender {
    [PasswordMaker.sharedInstance promptWithSuggestions:self usernames:NO action:^(NSString * _Nonnull response) {
        self.textView.text = response;
    }];
}

@end
