//
//  Alerts.m
//  StrongBox
//
//  Created by Mark on 29/05/2017.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import "Alerts.h"
#import "utils.h"
#import "AppPreferences.h"

#if TARGET_OS_IPHONE
#import <MobileCoreServices/MobileCoreServices.h>
#endif

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
    [self OkCancelWithPassword:viewController allowEmpty:NO completion:completion];
}

- (void)OkCancelWithPasswordAllowEmpty:(UIViewController *)viewController
                            completion:(void (^) (NSString *password, BOOL response))completion {
    [self OkCancelWithPassword:viewController allowEmpty:YES completion:completion];
}

- (void)OkCancelWithPassword:(UIViewController *)viewController
                  allowEmpty:(BOOL)allowEmpty
                  completion:(void (^) (NSString *password, BOOL response))completion {
    __weak typeof(self) weakSelf = self;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.alertController addTextFieldWithConfigurationHandler:^(UITextField *_Nonnull textField) {
            textField.secureTextEntry = YES;
            
            if ( !allowEmpty ) {
                [textField addTarget:weakSelf
                              action:@selector(validateNoneEmpty:)
                    forControlEvents:UIControlEventEditingChanged];
            }
        }];
        
        self.defaultAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"alerts_ok", @"OK")
                                                      style:UIAlertActionStyleDefault
                                                    handler:^(UIAlertAction *a) {
                                                        completion((self.alertController.textFields[0]).text, true);
                                                    }];
        
        
        self.defaultAction.enabled = allowEmpty;
        
        UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"generic_cancel", @"Cancel")
                                                               style:UIAlertActionStyleCancel
                                                             handler:^(UIAlertAction *a) {
                                                                 completion(nil, false);
                                                             }];
        
        [self.alertController addAction:self.defaultAction];
        [self.alertController addAction:cancelAction];

        [viewController presentViewController:self.alertController animated:YES completion:nil];
    });
}

- (void)OkCancelWithPasswordAndConfirm:(UIViewController *)viewController
                            allowEmpty:(BOOL)allowEmpty
                            completion:(void (^) (NSString *password, BOOL response))completion {
    __weak typeof(self) weakSelf = self;

    dispatch_async(dispatch_get_main_queue(), ^{
        SEL validation = allowEmpty ? @selector(validatePasswordAndConfirmPassword:) : @selector(validatePasswordAndConfirmPasswordNotEmpty:);
        
        [self.alertController addTextFieldWithConfigurationHandler:^(UITextField *_Nonnull textField) {
                              [textField addTarget:weakSelf
                                            action:validation
                                  forControlEvents:UIControlEventEditingChanged];
                              textField.placeholder = NSLocalizedString(@"alerts_password", @"Password");
                              textField.secureTextEntry = YES;
                          }];

        [self.alertController addTextFieldWithConfigurationHandler:^(UITextField *_Nonnull textField) {
                              [textField addTarget:weakSelf
                                            action:validation
                                  forControlEvents:UIControlEventEditingChanged];
                              textField.placeholder = NSLocalizedString(@"alerts_confirm_password", @"Confirm Password");
                              textField.secureTextEntry = YES;
                          }];

        self.defaultAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"alerts_ok", @"OK")
                                                      style:UIAlertActionStyleDefault
                                                    handler:^(UIAlertAction *a) {
                                                        completion(((self.alertController).textFields[0]).text, true);
                                                    }];
        
        self.defaultAction.enabled = allowEmpty;
        
        UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"generic_cancel", @"Cancel")
                                                               style:UIAlertActionStyleCancel
                                                             handler:^(UIAlertAction *a) {
                                                                 completion(nil, false);
                                                             }];

        [self.alertController addAction:self.defaultAction];
        [self.alertController addAction:cancelAction];

        [viewController presentViewController:self.alertController animated:YES completion:nil];
    });
}

- (void)validatePasswordAndConfirmPassword:(UITextField *)sender {
    UITextField *name = _alertController.textFields[0];
    UITextField *password = _alertController.textFields[1];

    (self.defaultAction).enabled = ([name.text compare:password.text] == NSOrderedSame);
}

- (void)validatePasswordAndConfirmPasswordNotEmpty:(UITextField *)sender {
    UITextField *name = _alertController.textFields[0];
    UITextField *password = _alertController.textFields[1];
    
    (self.defaultAction).enabled = name.text.length && ([name.text compare:password.text] == NSOrderedSame);
}

+ (void)okCancel:(UIViewController *)viewController
           title:(NSString *)title
         message:(NSString *)message
          action:(void (^) (BOOL response))action {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIAlertController *alertController = [UIAlertController alertControllerWithTitle:title
                                                                                 message:message
                                                                          preferredStyle:UIAlertControllerStyleAlert];


        UIAlertAction *defaultAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"alerts_ok", @"OK")
                                                                style:UIAlertActionStyleDefault
                                                              handler:^(UIAlertAction *a) { action(YES); }];

        UIAlertAction *noAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"generic_cancel", @"Cancel")
                                                           style:UIAlertActionStyleCancel
                                                         handler:^(UIAlertAction *a) { action(NO); }];

        [alertController addAction:defaultAction];
        [alertController addAction:noAction];

        [viewController presentViewController:alertController animated:YES completion:nil];
    });
}

+ (void)areYouSure:(UIViewController *)viewController message:(NSString *)message action:(void (^)(BOOL response))action {
    [Alerts yesNo:viewController
            title:NSLocalizedString(@"generic_are_you_sure", @"Are You Sure?")
          message:message
           action:action];
}

+ (void)yesNo:(UIViewController *)viewController
        title:(NSString *)title
      message:(NSString *)message
       action:(void (^) (BOOL response))action {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIAlertController *alertController = [UIAlertController alertControllerWithTitle:title
                                                                                 message:message
                                                                          preferredStyle:UIAlertControllerStyleAlert];


        UIAlertAction *defaultAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"alerts_yes", @"Yes")
                                                                style:UIAlertActionStyleDefault
                                                              handler:^(UIAlertAction *a) { action(YES); }];

        UIAlertAction *noAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"alerts_no", @"No")
                                                           style:UIAlertActionStyleCancel
                                                         handler:^(UIAlertAction *a) { action(NO); }];

        [alertController addAction:defaultAction];
        [alertController addAction:noAction];

        [viewController presentViewController:alertController animated:YES completion:nil];
    });
}

+ (void)   twoOptions:(UIViewController *)viewController
                title:(NSString *)title
              message:(NSString *)message
    defaultButtonText:(NSString *)defaultButtonText
     secondButtonText:(NSString *)secondButtonText
               action:(void (^) (BOOL response))action {
    dispatch_async(dispatch_get_main_queue(), ^{
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
    });
}

+ (void)error:(UIViewController *)viewController error:(NSError *)error {
    [Alerts error:viewController error:error completion:nil];
}

+ (void)error:(UIViewController *)viewController error:(const NSError *)error completion:(void (^)(void))completion {
    [Alerts error:viewController title:NSLocalizedString(@"generic_error", @"Error") error:error completion:completion];
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
    dispatch_async(dispatch_get_main_queue(), ^{
        UIAlertController *alertController = [UIAlertController alertControllerWithTitle:title
                                                                                 message:error ? error.localizedDescription :
                                              NSLocalizedString(@"alerts_unknown_error", @"Unknown Error")
                                                                          preferredStyle:UIAlertControllerStyleAlert];

        UIAlertAction *defaultAction = [UIAlertAction actionWithTitle:
                                        NSLocalizedString(@"alerts_ok", @"OK")
                                                                style:UIAlertActionStyleDefault
                                                              handler:^(UIAlertAction *a) { if(completion) { completion(); } }];

        [alertController addAction:defaultAction];

        [viewController presentViewController:alertController animated:YES completion:nil];
    });
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
    dispatch_async(dispatch_get_main_queue(), ^{
        UIAlertController *alertController = [UIAlertController alertControllerWithTitle:title
                                                                                 message:message
                                                                          preferredStyle:UIAlertControllerStyleAlert];

        UIAlertAction *defaultAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"alerts_ok", @"OK")
                                                                style:UIAlertActionStyleDefault
                                                              handler:^(UIAlertAction *a) { if (completion) {
                                                                                                completion();
                                                                                            }
                                                              }];

        [alertController addAction:defaultAction];

        [viewController presentViewController:alertController animated:YES completion:nil];
    });
}
                   

+ (void) threeOptions:(UIViewController *)viewController
                title:(NSString *)title
              message:(NSString *)message
    defaultButtonText:(NSString *)defaultButtonText
     secondButtonText:(NSString *)secondButtonText
      thirdButtonText:(NSString *)thirdButtonText
               action:(void (^) (int response))action {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIAlertController *alertController = [UIAlertController alertControllerWithTitle:title
                                                                                 message:message
                                                                          preferredStyle:UIAlertControllerStyleAlert];

        
        
        
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
    });
}

+ (void)oneOptionsWithCancel:(VIEW_CONTROLLER_PTR)viewController title:(NSString *)title message:(NSString *)message buttonText:(NSString *)buttonText action:(void (^)(BOOL response))action {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIAlertController *alertController = [UIAlertController alertControllerWithTitle:title
                                                                                 message:message
                                                                          preferredStyle:UIAlertControllerStyleAlert];
        
        
        
        
        UIAlertAction *defaultAction = [UIAlertAction actionWithTitle:buttonText
                                                                style:UIAlertActionStyleDefault
                                                              handler:^(UIAlertAction *a) { action(YES); }];
                
        UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"generic_cancel", @"Cancel")
                                                               style:UIAlertActionStyleCancel
                                                             handler:^(UIAlertAction *a) { action(NO); }];
        
        [alertController addAction:defaultAction];
        [alertController addAction:cancelAction];
    
        [viewController presentViewController:alertController animated:YES completion:nil];
    });
}

+ (void) twoOptionsWithCancel:(UIViewController *)viewController
                        title:(NSString *)title
                    message:(NSString *)message
            defaultButtonText:(NSString *)defaultButtonText
               secondButtonText:(NSString *)secondButtonText
                         action:(void (^) (int response))action {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIAlertController *alertController = [UIAlertController alertControllerWithTitle:title
                                                                                 message:message
                                                                          preferredStyle:UIAlertControllerStyleAlert];
        
        
        
        
        UIAlertAction *defaultAction = [UIAlertAction actionWithTitle:defaultButtonText
                                                                style:UIAlertActionStyleDefault
                                                              handler:^(UIAlertAction *a) { action(0); }];
        
        UIAlertAction *secondAction = [UIAlertAction actionWithTitle:secondButtonText
                                                               style:UIAlertActionStyleDefault
                                                             handler:^(UIAlertAction *a) { action(1); }];
        
        UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"generic_cancel", @"Cancel")
                                                               style:UIAlertActionStyleCancel
                                                             handler:^(UIAlertAction *a) { action(3); }];
        
        [alertController addAction:defaultAction];
        [alertController addAction:secondAction];
        [alertController addAction:cancelAction];
    
        [viewController presentViewController:alertController animated:YES completion:nil];
    });
}

+ (void) threeOptionsWithCancel:(UIViewController *)viewController
                          title:(NSString *)title
                        message:(NSString *)message
              defaultButtonText:(NSString *)defaultButtonText
               secondButtonText:(NSString *)secondButtonText
                thirdButtonText:(NSString *)thirdButtonText
                         action:(void (^) (int response))action {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIAlertController *alertController = [UIAlertController alertControllerWithTitle:title
                                                                                 message:message
                                                                          preferredStyle:UIAlertControllerStyleAlert];
        
        
        
        
        UIAlertAction *defaultAction = [UIAlertAction actionWithTitle:defaultButtonText
                                                                style:UIAlertActionStyleDefault
                                                              handler:^(UIAlertAction *a) { action(0); }];
        
        UIAlertAction *secondAction = [UIAlertAction actionWithTitle:secondButtonText
                                                               style:UIAlertActionStyleDefault
                                                             handler:^(UIAlertAction *a) { action(1); }];
        
        UIAlertAction *thirdAction = [UIAlertAction actionWithTitle:thirdButtonText
                                                              style:UIAlertActionStyleDefault
                                                            handler:^(UIAlertAction *a) { action(2); }];
        
        UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"generic_cancel", @"Cancel")
                                                               style:UIAlertActionStyleCancel
                                                             handler:^(UIAlertAction *a) { action(3); }];
        
        [alertController addAction:defaultAction];
        [alertController addAction:secondAction];
        [alertController addAction:thirdAction];
        [alertController addAction:cancelAction];
    
        [viewController presentViewController:alertController animated:YES completion:nil];
    });
}

+ (void) fourOptionsWithCancel:(UIViewController *)viewController
                         title:(NSString *)title
                       message:(NSString *)message
             defaultButtonText:(NSString *)defaultButtonText
              secondButtonText:(NSString *)secondButtonText
               thirdButtonText:(NSString *)thirdButtonText
              fourthButtonText:(NSString *)fourthButtonText
                        action:(void (^) (int response))action {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIAlertController *alertController = [UIAlertController alertControllerWithTitle:title
                                                                                 message:message
                                                                          preferredStyle:UIAlertControllerStyleAlert];
        
        
        
        UIAlertAction *defaultAction = [UIAlertAction actionWithTitle:defaultButtonText
                                                                style:UIAlertActionStyleDefault
                                                              handler:^(UIAlertAction *a) { action(0); }];
        
        UIAlertAction *secondAction = [UIAlertAction actionWithTitle:secondButtonText
                                                               style:UIAlertActionStyleDefault
                                                             handler:^(UIAlertAction *a) { action(1); }];
        
        UIAlertAction *thirdAction = [UIAlertAction actionWithTitle:thirdButtonText
                                                              style:UIAlertActionStyleDefault
                                                            handler:^(UIAlertAction *a) { action(2); }];
        
        UIAlertAction *fourthAction = [UIAlertAction actionWithTitle:fourthButtonText
                                                               style:UIAlertActionStyleDefault
                                                             handler:^(UIAlertAction *a) { action(3); }];
        
        UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"generic_cancel", @"Cancel")
                                                               style:UIAlertActionStyleCancel
                                                             handler:^(UIAlertAction *a) { action(4); }];
        
        [alertController addAction:defaultAction];
        [alertController addAction:secondAction];
        [alertController addAction:thirdAction];
        [alertController addAction:fourthAction];
        [alertController addAction:cancelAction];
    
        [viewController presentViewController:alertController animated:YES completion:nil];
    });
}

+ (void)OkCancelWithPassword:(UIViewController *)viewController
                       title:(NSString *)title
                     message:(NSString *)message
                  completion:(void (^) (NSString *password, BOOL response))completion {
    [self OkCancelWithTextField:viewController
                secureTextField:YES
           textFieldPlaceHolder:NSLocalizedString(@"alerts_password", @"Password")
                          title:title
                        message:message
                     completion:completion];
}

- (void)OkCancelWithTextFieldNotEmpty:(UIViewController *)viewController
                textFieldText:(NSString *)textFieldText
                   completion:(void (^) (NSString *text, BOOL response))completion {
    __weak typeof(self) weakSelf = self;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.alertController addTextFieldWithConfigurationHandler:^(UITextField *_Nonnull textField) {
            [textField addTarget:weakSelf
                          action:@selector(validateNoneEmpty:)
                forControlEvents:UIControlEventEditingChanged];
        
            textField.text = [textFieldText length] ? textFieldText : NSLocalizedString(@"alerts_not_empty", @"Not Empty!");
       
            int extensionLength = textFieldText.pathExtension ? (int)textFieldText.pathExtension.length : 0;

            UITextPosition *startPosition = [textField positionFromPosition:textField.beginningOfDocument offset:0];
            UITextPosition *endPosition = [textField positionFromPosition:textField.endOfDocument offset:-extensionLength];
            UITextRange *selection = [textField textRangeFromPosition:startPosition toPosition:endPosition];

            [textField setSelectedTextRange:selection];
        }];
        
        self.defaultAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"alerts_ok", @"OK")
                                                                style:UIAlertActionStyleDefault
                                                              handler:^(UIAlertAction *a) {
                                                                  completion((self.alertController.textFields[0]).text, true);
                                                              }];
        
        UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"generic_cancel", @"Cancel")
                                                               style:UIAlertActionStyleCancel
                                                             handler:^(UIAlertAction *a) {
                                                                 completion(nil, false);
                                                             }];
        
        [self.alertController addAction:self.defaultAction];
        [self.alertController addAction:cancelAction];
    
        [viewController presentViewController:self.alertController animated:YES completion:nil];
    });
}

- (void)validateNoneEmpty:(UITextField *)sender {
    self.defaultAction.enabled = sender.text.length;
}

- (void)validateNop:(UITextField *)sender {
    self.defaultAction.enabled = YES;
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
                textFieldText:(NSString *)textFieldText
                        title:(NSString *)title
                      message:(NSString *)message
                   completion:(void (^) (NSString *text, BOOL response))completion {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIAlertController *alertController = [UIAlertController alertControllerWithTitle:title
                                                                                 message:message
                                                                          preferredStyle:UIAlertControllerStyleAlert];
        [alertController addTextFieldWithConfigurationHandler:^(UITextField *_Nonnull textField) {
            textField.text = textFieldText;
        }];
        
        UIAlertAction *defaultAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"alerts_ok", @"OK")
                                                                style:UIAlertActionStyleDefault
                                                              handler:^(UIAlertAction *a) {
            completion((alertController.textFields[0]).text, true);
        }];
        
        UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"generic_cancel", @"Cancel")
                                                               style:UIAlertActionStyleCancel
                                                             handler:^(UIAlertAction *a) {
            completion(nil, false);
        }];
        
        [alertController addAction:defaultAction];
        [alertController addAction:cancelAction];
        
        [viewController presentViewController:alertController animated:YES completion:nil];
    });
}

+ (void)OkCancelWithTextField:(UIViewController *)viewController
              secureTextField:(BOOL)secureTextField
         textFieldPlaceHolder:(NSString *)textFieldPlaceHolder
                        title:(NSString *)title
                      message:(NSString *)message
                   completion:(void (^) (NSString *password, BOOL response))completion {
    [Alerts OkCancelWithTextField:viewController secureTextField:secureTextField textFieldPlaceHolder:textFieldPlaceHolder textFieldText:@"" title:title message:message completion:completion];
}

+ (void)OkCancelWithTextField:(UIViewController *)viewController
              secureTextField:(BOOL)secureTextField
         textFieldPlaceHolder:(NSString *)textFieldPlaceHolder
                textFieldText:(NSString *)textFieldText
                        title:(NSString *)title
                      message:(NSString *)message
                   completion:(void (^) (NSString *password, BOOL response))completion {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIAlertController *alertController = [UIAlertController alertControllerWithTitle:title
                                                                                 message:message
                                                                          preferredStyle:UIAlertControllerStyleAlert];

        [alertController addTextFieldWithConfigurationHandler:^(UITextField *_Nonnull textField) {
                             textField.placeholder = textFieldPlaceHolder;
                             textField.secureTextEntry = secureTextField;
                             textField.text = textFieldText;
                         }];

        UIAlertAction *defaultAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"alerts_ok", @"OK")
                                                                style:UIAlertActionStyleDefault
                                                              handler:^(UIAlertAction *a) {
                                                                  completion((alertController.textFields[0]).text, true);
                                                              }];

        UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"generic_cancel", @"Cancel")
                                                               style:UIAlertActionStyleCancel
                                                             handler:^(UIAlertAction *a) {
                                                                 completion(nil, false);
                                                             }];

        [alertController addAction:defaultAction];
        [alertController addAction:cancelAction];

        [viewController presentViewController:alertController animated:YES completion:nil];
    });
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
    dispatch_async(dispatch_get_main_queue(), ^{
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

        UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"generic_cancel", @"Cancel")
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
    });
}

+ (void)checkThirdPartyLibOptInOK:(UIViewController *)viewController completion:(void (^)(BOOL optInOk))completion {
    if ( AppPreferences.sharedInstance.userHasOptedInToThirdPartyStorageLibraries ) {
        completion(YES);
        return;
    }
    
    [Alerts oneOptionsWithCancel:viewController
                           title:NSLocalizedString(@"third_party_storage_privacy_opt_in_title", @"Third Party Storage Privacy Opt-In")
                         message:NSLocalizedString(@"third_party_storage_privacy_opt_in_message", @"You are about to use a software library from Google, Microsoft or Dropbox for the first time to access your cloud files.\n\nStrongbox does not control these organizations privacy policies (which may not be awesome).\n\nStrongbox offers these services for your convenience and it is entirely at your discretion whether you use them or not. See our support articles for more info.")
                      buttonText:NSLocalizedString(@"third_party_storage_privacy_option_opt_in", @"That's cool, opt in...")
                          action:^(BOOL response) {
        if ( response ) {
            AppPreferences.sharedInstance.userHasOptedInToThirdPartyStorageLibraries = YES;
        }
        
        completion(response);
    }];
}

@end
