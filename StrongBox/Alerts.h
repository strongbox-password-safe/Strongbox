//
//  Alerts.h
//  StrongBox
//
//  Created by Mark on 29/05/2017.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>


#if TARGET_OS_IPHONE
    #import <UIKit/UIKit.h>
    typedef UIViewController* VIEW_CONTROLLER_PTR;
//    typedef UIImage* IMAGE_TYPE_PTR;
//    typedef DatabasePreferences* METADATA_PTR;
#else
    #import <Cocoa/Cocoa.h>
    typedef NSViewController* VIEW_CONTROLLER_PTR;


#endif


@interface Alerts : NSObject

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithTitle:(NSString *)title message:(NSString *)message NS_DESIGNATED_INITIALIZER;

- (void)OkCancelWithPasswordAndConfirm:(VIEW_CONTROLLER_PTR)viewController
                            allowEmpty:(BOOL)allowEmpty
                            completion:(void (^)(NSString *password, BOOL response))completion;

+ (void)areYouSure:(VIEW_CONTROLLER_PTR)viewController message:(NSString*)message action:(void (^) (BOOL response))action;

+ (void)yesNo:(VIEW_CONTROLLER_PTR)viewController
        title:(NSString *)title
      message:(NSString *)message
       action:(void (^)(BOOL response))action;

+ (void)okCancel:(VIEW_CONTROLLER_PTR)viewController
           title:(NSString *)title
         message:(NSString *)message
          action:(void (^)(BOOL response))action;

+ (void)error:(VIEW_CONTROLLER_PTR)viewController error:(const NSError *)error;

+ (void)error:(VIEW_CONTROLLER_PTR)viewController error:(const NSError *)error completion:(void (^)(void))completion;

+ (void)error:(VIEW_CONTROLLER_PTR)viewController
        title:(NSString *)title
        error:(const NSError *)error;

+ (void)error:(VIEW_CONTROLLER_PTR)viewController
        title:(NSString *)title
        error:(const NSError *)error
   completion:(void (^)(void))completion;

+ (void)warn:(VIEW_CONTROLLER_PTR)viewController
       title:(NSString *)title
     message:(NSString *)message;

+ (void)  warn:(VIEW_CONTROLLER_PTR)viewController
         title:(NSString *)title
       message:(NSString *)message
    completion:(void (^)(void))completion;

+ (void)info:(VIEW_CONTROLLER_PTR)viewController
       title:(NSString *)title
     message:(NSString *)message;


+ (void)  info:(VIEW_CONTROLLER_PTR)viewController
         title:(NSString *)title
       message:(NSString *)message
    completion:(void (^)(void))completion;

+ (void)   oneOptionsWithCancel:(VIEW_CONTROLLER_PTR)viewController
                          title:(NSString *)title
                        message:(NSString *)message
                     buttonText:(NSString *)buttonText
                         action:(void (^) (BOOL response))action;

+ (void)   twoOptionsWithCancel:(VIEW_CONTROLLER_PTR)viewController
                    title:(NSString *)title
                  message:(NSString *)message
        defaultButtonText:(NSString *)defaultButtonText
         secondButtonText:(NSString *)secondButtonText
                   action:(void (^) (int response))action;

+ (void)   twoOptions:(VIEW_CONTROLLER_PTR)viewController
                title:(NSString *)title
              message:(NSString *)message
    defaultButtonText:(NSString *)defaultButtonText
     secondButtonText:(NSString *)secondButtonText
               action:(void (^)(BOOL response))action;

+ (void) threeOptions:(VIEW_CONTROLLER_PTR)viewController
                title:(NSString *)title
              message:(NSString *)message
    defaultButtonText:(NSString *)defaultButtonText
     secondButtonText:(NSString *)secondButtonText
      thirdButtonText:(NSString *)thirdButtonText
               action:(void (^)(int response))action;

+ (void) threeOptionsWithCancel:(VIEW_CONTROLLER_PTR)viewController
                          title:(NSString *)title
                        message:(NSString *)message
              defaultButtonText:(NSString *)defaultButtonText
               secondButtonText:(NSString *)secondButtonText
                thirdButtonText:(NSString *)thirdButtonText
                         action:(void (^) (int response))action;

+ (void) fourOptionsWithCancel:(UIViewController *)viewController
                         title:(NSString *)title
                       message:(NSString *)message
             defaultButtonText:(NSString *)defaultButtonText
              secondButtonText:(NSString *)secondButtonText
               thirdButtonText:(NSString *)thirdButtonText
              fourthButtonText:(NSString *)fourthButtonText
                        action:(void (^) (int response))action;

+ (void)OkCancelWithPassword:(VIEW_CONTROLLER_PTR)viewController
                       title:(NSString *)title
                     message:(NSString *)message
                  completion:(void (^)(NSString *password, BOOL response))completion;

+ (void)OkCancelWithTextField:(VIEW_CONTROLLER_PTR)viewController
                textFieldText:(NSString *)textFieldText
                        title:(NSString *)title
                      message:(NSString *)message
                   completion:(void (^) (NSString *text, BOOL response))completion;

+ (void)OkCancelWithTextField:(VIEW_CONTROLLER_PTR)viewController
         textFieldPlaceHolder:(NSString *)textFieldPlaceHolder
                        title:(NSString *)title
                      message:(NSString *)message
                   completion:(void (^)(NSString *text, BOOL response))completion;

+ (void)actionSheet:(VIEW_CONTROLLER_PTR)viewController
               rect:(CGRect)rect
              title:(NSString *)title
       buttonTitles:(NSArray<NSString *> *)buttonTitles
         completion:(void (^)(int response))completion;

- (void)OkCancelWithTextFieldNotEmpty:(VIEW_CONTROLLER_PTR)viewController
                        textFieldText:(NSString *)textFieldText
                           completion:(void (^) (NSString *text, BOOL response))completion;

- (void)OkCancelWithPasswordAllowEmpty:(UIViewController *)viewController
                            completion:(void (^) (NSString *password, BOOL response))completion;

- (void)OkCancelWithPasswordNonEmpty:(VIEW_CONTROLLER_PTR)viewController
                          completion:(void (^) (NSString *password, BOOL response))completion;

+ (void)OkCancelWithTextField:(UIViewController *)viewController
              secureTextField:(BOOL)secureTextField
         textFieldPlaceHolder:(NSString *)textFieldPlaceHolder
                textFieldText:(NSString *)textFieldText
                        title:(NSString *)title
                      message:(NSString *)message
                   completion:(void (^) (NSString *password, BOOL response))completion;

#if TARGET_OS_IPHONE

+ (void)actionSheet:(VIEW_CONTROLLER_PTR)viewController
          barButton:(UIBarButtonItem *)barButton
              title:(NSString *)title
       buttonTitles:(NSArray<NSString *> *)buttonTitles
         completion:(void (^)(int response))completion;

#endif

+ (void)checkThirdPartyLibOptInOK:(UIViewController*)viewController completion:(void (^)(BOOL optInOK))completion;

@end
