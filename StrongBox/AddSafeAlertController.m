//
//  AddSafeAlertController.m
//  StrongBox
//
//  Created by Mark on 30/05/2017.
//  Copyright © 2017 Mark McGuill. All rights reserved.
//

#import "AddSafeAlertController.h"
#import "IOsUtils.h"
#import "SafesList.h"

@implementation AddSafeAlertController {
    UIAlertAction *_defaultAction;
    UIAlertController *_alertController;
    ExistingValidation _existingValidation;
    NewValidation _newValidation;
}

- (NSString*)getSuggestedSafeName {
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

- (void)addNew:(UIViewController *)viewController
    validation:(BOOL (^) (NSString *name, NSString *password))validation
    completion:(void (^) (NSString *name, NSString *password, BOOL response))completion {
    _newValidation = validation;
    _alertController = [UIAlertController alertControllerWithTitle:@"Create New Database"
                                                           message:@"Enter a name for this database, and a master password"
                                                    preferredStyle:UIAlertControllerStyleAlert];

    NSString *suggestedName = [self getSuggestedSafeName];
    __block UITextField* nameTextField;

    __weak typeof(self) weakSelf = self;
    [_alertController addTextFieldWithConfigurationHandler:^(UITextField *_Nonnull textField) {
                          [textField addTarget:weakSelf
                                        action:@selector(validateAddNewFieldNotEmpty:)
                                forControlEvents:UIControlEventEditingChanged];
                            if(suggestedName.length) {
                                textField.text = suggestedName;
                            }
                            else {
                                textField.placeholder = @"Database Name";
                            }
        nameTextField = textField;
                      }];

    __block UITextField* passwordTextField;
    [_alertController addTextFieldWithConfigurationHandler:^(UITextField *_Nonnull textField) {
                          [textField                   addTarget:weakSelf
                                        action:@selector(validateAddNewFieldNotEmpty:)
                              forControlEvents:UIControlEventEditingChanged];
                          textField.placeholder = @"Master Password";
                          textField.secureTextEntry = YES;
                            passwordTextField = textField;
                          [textField becomeFirstResponder];
                      }];

    _defaultAction = [UIAlertAction actionWithTitle:@"Create"
                                              style:UIAlertActionStyleDefault
                                            handler:^(UIAlertAction *a) {
                                                completion((self->_alertController.textFields[0]).text, (self->_alertController.textFields[1]).text, true);
                                            }];
    [_defaultAction setEnabled:NO];

    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"Cancel"
                                                           style:UIAlertActionStyleCancel
                                                         handler:^(UIAlertAction *a) {
                                                             completion(nil, nil, false);
                                                         }];

    [_alertController addAction:_defaultAction];
    [_alertController addAction:cancelAction];

    [viewController presentViewController:_alertController animated:YES completion:^{
        if(suggestedName.length) {
            [passwordTextField becomeFirstResponder];
        }
        else {
            [nameTextField becomeFirstResponder];
        }
    }];
}

- (void)addExisting:(UIViewController *)viewController
         validation:(BOOL (^) (NSString *name))validation
         completion:(void (^) (NSString *name, BOOL response))completion {
    _existingValidation = validation;
    _alertController = [UIAlertController alertControllerWithTitle:@"Add Database"
                                                           message:@"Enter a title or name for this database"
                                                    preferredStyle:UIAlertControllerStyleAlert];

    NSString *suggestedName = [self getSuggestedSafeName];
    
    _defaultAction = [UIAlertAction actionWithTitle:@"Add Database"
                                              style:UIAlertActionStyleDefault
                                            handler:^(UIAlertAction *a) {
                                                completion((self->_alertController.textFields[0]).text, true);
                                            }];
    [_defaultAction setEnabled:suggestedName != nil];
    
    __weak typeof(self) weakSelf = self;
    [_alertController addTextFieldWithConfigurationHandler:^(UITextField *_Nonnull textField) {
                          [textField                   addTarget:weakSelf
                                        action:@selector(validateAddExisting:)
                              forControlEvents:UIControlEventEditingChanged];
                            if(suggestedName) {
                                textField.text = suggestedName;
                            }
                            else {
                                textField.placeholder = @"Database Name";
                            }
                      }];

    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"Cancel"
                                                           style:UIAlertActionStyleCancel
                                                         handler:^(UIAlertAction *a) {
                                                             completion(nil, false);
                                                         }];

    [_alertController addAction:_defaultAction];
    [_alertController addAction:cancelAction];

    [viewController presentViewController:_alertController animated:YES completion:nil];
}

- (void)validateAddExisting:(UITextField *)sender {
    UITextField *name = _alertController.textFields[0];

    _defaultAction.enabled = _existingValidation(name.text);
}

- (void)validateAddNewFieldNotEmpty:(UITextField *)sender {
    UITextField *name = _alertController.textFields[0];
    UITextField *password = _alertController.textFields[1];

    _defaultAction.enabled = _newValidation(name.text, password.text);
}

@end
