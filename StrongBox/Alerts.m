//
//  Alerts.m
//  StrongBox
//
//  Created by Mark on 29/05/2017.
//  Copyright © 2017 Mark McGuill. All rights reserved.
//

#import "Alerts.h"
#import <MobileCoreServices/MobileCoreServices.h>
#import "Utils.h"

@interface Alerts ()

@property (nonatomic, strong) UIAlertController *alertController;
@property (nonatomic, strong) UIAlertAction *defaultAction;

@end

@implementation Alerts

- (instancetype)initWithTitle:(NSString *)title message:(NSString *)message {
    if (self = [super init]) {
        self.alertController = [UIAlertController alertControllerWithTitle:title
                                                                   message:message
                                                            preferredStyle:UIAlertControllerStyleAlert];
    }

    return self;
}

- (void)OkCancelWithPasswordNonEmpty:(UIViewController *)viewController
                          completion:(void (^) (NSString *password, BOOL response))completion {
    __weak typeof(self) weakSelf = self;
    
    [self.alertController addTextFieldWithConfigurationHandler:^(UITextField *_Nonnull textField) {
        textField.secureTextEntry = YES;
        [textField addTarget:weakSelf
                      action:@selector(validateNoneEmpty:)
            forControlEvents:UIControlEventEditingChanged];
    }];
    
    self.defaultAction = [UIAlertAction actionWithTitle:@"OK"
                                                  style:UIAlertActionStyleDefault
                                                handler:^(UIAlertAction *a) {
                                                    completion((self.alertController.textFields[0]).text, true);
                                                }];
    
    
    self.defaultAction.enabled = NO;
    
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"Cancel"
                                                           style:UIAlertActionStyleCancel
                                                         handler:^(UIAlertAction *a) {
                                                             completion(nil, false);
                                                         }];
    
    [self.alertController addAction:self.defaultAction];
    [self.alertController addAction:cancelAction];
    
    [viewController presentViewController:self.alertController animated:YES completion:nil];
}

- (void)OkCancelWithPasswordAndConfirm:(UIViewController *)viewController
                            allowEmpty:(BOOL)allowEmpty
                            completion:(void (^) (NSString *password, BOOL response))completion {
    __weak typeof(self) weakSelf = self;

    SEL validation = allowEmpty ? @selector(validatePasswordAndConfirmPassword:) : @selector(validatePasswordAndConfirmPasswordNotEmpty:);
    
    [_alertController addTextFieldWithConfigurationHandler:^(UITextField *_Nonnull textField) {
                          [textField addTarget:weakSelf
                                        action:validation
                              forControlEvents:UIControlEventEditingChanged];
                          textField.placeholder = @"Password";
                          textField.secureTextEntry = YES;
                      }];

    [_alertController addTextFieldWithConfigurationHandler:^(UITextField *_Nonnull textField) {
                          [textField addTarget:weakSelf
                                        action:validation
                              forControlEvents:UIControlEventEditingChanged];
                          textField.placeholder = @"Confirm Password";
                          textField.secureTextEntry = YES;
                      }];

    self.defaultAction = [UIAlertAction actionWithTitle:@"OK"
                                                  style:UIAlertActionStyleDefault
                                                handler:^(UIAlertAction *a) {
                                                    completion(((self.alertController).textFields[0]).text, true);
                                                }];
    
    self.defaultAction.enabled = allowEmpty;
    
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"Cancel"
                                                           style:UIAlertActionStyleCancel
                                                         handler:^(UIAlertAction *a) {
                                                             completion(nil, false);
                                                         }];

    [self.alertController addAction:self.defaultAction];
    [self.alertController addAction:cancelAction];

    [viewController presentViewController:self.alertController animated:YES completion:nil];
}

- (void)validatePasswordAndConfirmPassword:(UITextField *)sender {
    UITextField *name = _alertController.textFields[0];
    UITextField *password = _alertController.textFields[1];

    (self.defaultAction).enabled = ([name.text isEqualToString:password.text]);
}

- (void)validatePasswordAndConfirmPasswordNotEmpty:(UITextField *)sender {
    UITextField *name = _alertController.textFields[0];
    UITextField *password = _alertController.textFields[1];
    
    (self.defaultAction).enabled = name.text.length && ([name.text isEqualToString:password.text]);
}

+ (void)okCancel:(UIViewController *)viewController
           title:(NSString *)title
         message:(NSString *)message
          action:(void (^) (BOOL response))action {
    [self twoOptions:viewController
                    title:title
                  message:message
        defaultButtonText:@"OK"
         secondButtonText:@"Cancel"
                   action:action];
}

+ (void)yesNo:(UIViewController *)viewController
        title:(NSString *)title
      message:(NSString *)message
       action:(void (^) (BOOL response))action {
    [self twoOptions:viewController
                    title:title
                  message:message
        defaultButtonText:@"Yes"
         secondButtonText:@"No"
                   action:action];
}

+ (void)   twoOptions:(UIViewController *)viewController
                title:(NSString *)title
              message:(NSString *)message
    defaultButtonText:(NSString *)defaultButtonText
     secondButtonText:(NSString *)secondButtonText
               action:(void (^) (BOOL response))action {
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:title
                                                                             message:message
                                                                      preferredStyle:UIAlertControllerStyleAlert];


    UIAlertAction *defaultAction = [UIAlertAction actionWithTitle:defaultButtonText
                                                            style:UIAlertActionStyleDefault
                                                          handler:^(UIAlertAction *a) { action(YES); }];

    UIAlertAction *noAction = [UIAlertAction actionWithTitle:secondButtonText
                                                       style:UIAlertActionStyleCancel
                                                     handler:^(UIAlertAction *a) { action(NO); }];

    [alertController addAction:defaultAction];
    [alertController addAction:noAction];

    [viewController presentViewController:alertController animated:YES completion:nil];
}

+ (void)error:(UIViewController *)viewController
        title:(NSString *)title
        error:(NSError *)error {
    [Alerts error:viewController title:title error:error completion:nil];
}

+ (void)error:(UIViewController *)viewController
        title:(NSString *)title
        error:(NSError *)error
   completion:(void (^)(void))completion
{
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:title
                                                                             message:error ? error.localizedDescription : @"Unknown Error"
                                                                      preferredStyle:UIAlertControllerStyleAlert];

    UIAlertAction *defaultAction = [UIAlertAction actionWithTitle:@"OK"
                                                            style:UIAlertActionStyleDefault
                                                          handler:^(UIAlertAction *a) { }];

    [alertController addAction:defaultAction];

    [viewController presentViewController:alertController animated:YES completion:completion];
}

+ (void)warn:(UIViewController *)viewController
       title:(NSString *)title
     message:(NSString *)message {
    [self warnOrInfo:viewController title:title message:message completion:nil];
}

+ (void)  warn:(UIViewController *)viewController
         title:(NSString *)title
       message:(NSString *)message
    completion:(void (^) (void))completion {
    [self warnOrInfo:viewController title:title message:message completion:completion];
}

+ (void)  info:(UIViewController *)viewController
         title:(NSString *)title
       message:(NSString *)message
    completion:(void (^) (void))completion {
    [self warnOrInfo:viewController title:title message:message completion:completion];
}

+ (void)info:(UIViewController *)viewController
       title:(NSString *)title
     message:(NSString *)message {
    [self warnOrInfo:viewController title:title message:message completion:nil];
}

+ (void)warnOrInfo:(UIViewController *)viewController
             title:(NSString *)title
           message:(NSString *)message
        completion:(void (^) (void))completion {
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:title
                                                                             message:message
                                                                      preferredStyle:UIAlertControllerStyleAlert];

    UIAlertAction *defaultAction = [UIAlertAction actionWithTitle:@"OK"
                                                            style:UIAlertActionStyleDefault
                                                          handler:^(UIAlertAction *a) { if (completion) {
                                                                                            completion();
                                                                                        }
                                                          }];

    [alertController addAction:defaultAction];

    [viewController presentViewController:alertController animated:YES completion:nil];
}

+ (void) threeOptions:(UIViewController *)viewController
                title:(NSString *)title
              message:(NSString *)message
    defaultButtonText:(NSString *)defaultButtonText
     secondButtonText:(NSString *)secondButtonText
      thirdButtonText:(NSString *)thirdButtonText
               action:(void (^) (int response))action {
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:title
                                                                             message:message
                                                                      preferredStyle:UIAlertControllerStyleAlert];

    // this is the center of the screen currently but it can be any point in the view
    
    
    UIAlertAction *defaultAction = [UIAlertAction actionWithTitle:defaultButtonText
                                                            style:UIAlertActionStyleDefault
                                                          handler:^(UIAlertAction *a) { action(0); }];

    UIAlertAction *secondAction = [UIAlertAction actionWithTitle:secondButtonText
                                                           style:UIAlertActionStyleDefault
                                                         handler:^(UIAlertAction *a) { action(1); }];

    UIAlertAction *thirdAction = [UIAlertAction actionWithTitle:thirdButtonText
                                                          style:UIAlertActionStyleCancel
                                                        handler:^(UIAlertAction *a) { action(2); }];

    [alertController addAction:defaultAction];
    [alertController addAction:secondAction];
    [alertController addAction:thirdAction];

    [viewController presentViewController:alertController animated:YES completion:nil];
}

+ (void) threeOptionsWithCancel:(UIViewController *)viewController
                          title:(NSString *)title
                        message:(NSString *)message
              defaultButtonText:(NSString *)defaultButtonText
               secondButtonText:(NSString *)secondButtonText
                thirdButtonText:(NSString *)thirdButtonText
                         action:(void (^) (int response))action {
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:title
                                                                             message:message
                                                                      preferredStyle:UIAlertControllerStyleAlert];
    
    // this is the center of the screen currently but it can be any point in the view
    
    
    UIAlertAction *defaultAction = [UIAlertAction actionWithTitle:defaultButtonText
                                                            style:UIAlertActionStyleDefault
                                                          handler:^(UIAlertAction *a) { action(0); }];
    
    UIAlertAction *secondAction = [UIAlertAction actionWithTitle:secondButtonText
                                                           style:UIAlertActionStyleDefault
                                                         handler:^(UIAlertAction *a) { action(1); }];
    
    UIAlertAction *thirdAction = [UIAlertAction actionWithTitle:thirdButtonText
                                                          style:UIAlertActionStyleDefault
                                                        handler:^(UIAlertAction *a) { action(2); }];
    
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"Cancel"
                                                           style:UIAlertActionStyleCancel
                                                         handler:^(UIAlertAction *a) { action(3); }];
    
    [alertController addAction:defaultAction];
    [alertController addAction:secondAction];
    [alertController addAction:thirdAction];
    [alertController addAction:cancelAction];
    
    [viewController presentViewController:alertController animated:YES completion:nil];
}

+ (void)OkCancelWithPassword:(UIViewController *)viewController
                       title:(NSString *)title
                     message:(NSString *)message
                  completion:(void (^) (NSString *password, BOOL response))completion {
    [self OkCancelWithTextField:viewController
                secureTextField:YES
           textFieldPlaceHolder:@"Password"
                          title:title
                        message:message
                     completion:completion];
}

+ (void)OkCancelWithTextField:(UIViewController *)viewController
                textFieldText:(NSString *)textFieldText
                        title:(NSString *)title
                      message:(NSString *)message
                   completion:(void (^) (NSString *text, BOOL response))completion {
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:title
                                                                             message:message
                                                                      preferredStyle:UIAlertControllerStyleAlert];
    [alertController addTextFieldWithConfigurationHandler:^(UITextField *_Nonnull textField) {
        textField.text = textFieldText;
    }];
    
    UIAlertAction *defaultAction = [UIAlertAction actionWithTitle:@"OK"
                                                  style:UIAlertActionStyleDefault
                                                handler:^(UIAlertAction *a) {
                                                    completion((alertController.textFields[0]).text, true);
                                                }];
    
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"Cancel"
                                                           style:UIAlertActionStyleCancel
                                                         handler:^(UIAlertAction *a) {
                                                             completion(nil, false);
                                                         }];
    
    [alertController addAction:defaultAction];
    [alertController addAction:cancelAction];
    
    [viewController presentViewController:alertController animated:YES completion:nil];
}

- (void)OkCancelWithTextFieldNotEmpty:(UIViewController *)viewController
                textFieldText:(NSString *)textFieldText
                   completion:(void (^) (NSString *text, BOOL response))completion {
    __weak typeof(self) weakSelf = self;

    [self.alertController addTextFieldWithConfigurationHandler:^(UITextField *_Nonnull textField) {
        [textField addTarget:weakSelf
                      action:@selector(validateNoneEmpty:)
            forControlEvents:UIControlEventEditingChanged];
    
        textField.text = [textFieldText length] ? textFieldText : @"Not Empty!";
   
        int extensionLength = textFieldText.pathExtension ? (int)textFieldText.pathExtension.length : 0;

        UITextPosition *startPosition = [textField positionFromPosition:textField.beginningOfDocument offset:0];
        UITextPosition *endPosition = [textField positionFromPosition:textField.endOfDocument offset:-extensionLength];
        UITextRange *selection = [textField textRangeFromPosition:startPosition toPosition:endPosition];

        [textField setSelectedTextRange:selection];
    }];
    
    self.defaultAction = [UIAlertAction actionWithTitle:@"OK"
                                                            style:UIAlertActionStyleDefault
                                                          handler:^(UIAlertAction *a) {
                                                              completion((self.alertController.textFields[0]).text, true);
                                                          }];
    
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"Cancel"
                                                           style:UIAlertActionStyleCancel
                                                         handler:^(UIAlertAction *a) {
                                                             completion(nil, false);
                                                         }];
    
    [self.alertController addAction:self.defaultAction];
    [self.alertController addAction:cancelAction];
    
    [viewController presentViewController:self.alertController animated:YES completion:nil];
}

- (void)validateNoneEmpty:(UITextField *)sender {
    self.defaultAction.enabled = sender.text.length;
}

+ (void)OkCancelWithTextField:(UIViewController *)viewController
         textFieldPlaceHolder:(NSString *)textFieldPlaceHolder
                        title:(NSString *)title
                      message:(NSString *)message
                   completion:(void (^) (NSString *text, BOOL response))completion {
    [self OkCancelWithTextField:viewController
                secureTextField:NO
           textFieldPlaceHolder:textFieldPlaceHolder
                          title:title
                        message:message
                     completion:completion];
}

+ (void)OkCancelWithTextField:(UIViewController *)viewController
              secureTextField:(BOOL)secureTextField
         textFieldPlaceHolder:(NSString *)textFieldPlaceHolder
                        title:(NSString *)title
                      message:(NSString *)message
                   completion:(void (^) (NSString *password, BOOL response))completion {
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:title
                                                                             message:message
                                                                      preferredStyle:UIAlertControllerStyleAlert];

    [alertController addTextFieldWithConfigurationHandler:^(UITextField *_Nonnull textField) {
                         textField.placeholder = textFieldPlaceHolder;
                         textField.secureTextEntry = secureTextField;
                     }];

    UIAlertAction *defaultAction = [UIAlertAction actionWithTitle:@"OK"
                                                            style:UIAlertActionStyleDefault
                                                          handler:^(UIAlertAction *a) {
                                                              completion((alertController.textFields[0]).text, true);
                                                          }];

    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"Cancel"
                                                           style:UIAlertActionStyleCancel
                                                         handler:^(UIAlertAction *a) {
                                                             completion(nil, false);
                                                         }];

    [alertController addAction:defaultAction];
    [alertController addAction:cancelAction];

    [viewController presentViewController:alertController animated:YES completion:nil];
}

+ (void)actionSheet:(UIViewController *)viewController
          barButton:(UIBarButtonItem *)barButton
              title:(NSString *)title
       buttonTitles:(NSArray<NSString *> *)buttonTitles
         completion:(void (^) (int response))completion
{
    [self actionSheet:viewController barButton:barButton rect:CGRectZero title:title buttonTitles:buttonTitles completion:completion];
}

+ (void)actionSheet:(UIViewController *)viewController
               rect:(CGRect)rect
              title:(NSString *)title
       buttonTitles:(NSArray<NSString *> *)buttonTitles
         completion:(void (^)(int response))completion
{
    [self actionSheet:viewController barButton:nil rect:rect title:title buttonTitles:buttonTitles completion:completion];
}

+ (void)actionSheet:(UIViewController *)viewController
          barButton:(UIBarButtonItem *)barButton
               rect:(CGRect)rect
              title:(NSString *)title
       buttonTitles:(NSArray<NSString *> *)buttonTitles
         completion:(void (^)(int response))completion;

{
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:title
                                                                             message:nil
                                                                      preferredStyle:UIAlertControllerStyleActionSheet];

    int index = 1;

    for (NSString *title in buttonTitles) {
        UIAlertAction *action = [UIAlertAction actionWithTitle:title
                                                         style:UIAlertActionStyleDefault
                                                       handler:^(UIAlertAction *a) {
                                                           completion(index);
                                                       }];

        [alertController addAction:action];
        index++;
    }

    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"Cancel"
                                                           style:UIAlertActionStyleCancel
                                                         handler:^(UIAlertAction *a) {
                                                             completion(0);
                                                         }];
    [alertController addAction:cancelAction];

    
    if(barButton) {
        alertController.popoverPresentationController.barButtonItem = barButton;
    }
    else {
        alertController.popoverPresentationController.sourceView = viewController.view;
        alertController.popoverPresentationController.sourceRect = rect;
    }
    
    [viewController presentViewController:alertController animated:YES completion:nil];
}

@end
