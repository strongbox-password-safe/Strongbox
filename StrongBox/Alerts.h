//
//  Alerts.h
//  StrongBox
//
//  Created by Mark on 29/05/2017.
//  Copyright © 2017 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface Alerts : NSObject

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithTitle:(NSString *)title message:(NSString *)message NS_DESIGNATED_INITIALIZER;

- (void)OkCancelWithPasswordAndConfirm:(UIViewController *)viewController
                            allowEmpty:(BOOL)allowEmpty
                            completion:(void (^)(NSString *password, BOOL response))completion;


+ (void)yesNo:(UIViewController *)viewController
        title:(NSString *)title
      message:(NSString *)message
       action:(void (^)(BOOL response))action;

+ (void)okCancel:(UIViewController *)viewController
           title:(NSString *)title
         message:(NSString *)message
          action:(void (^)(BOOL response))action;

+ (void)error:(UIViewController *)viewController error:(NSError *)error;

+ (void)error:(UIViewController *)viewController
        title:(NSString *)title
        error:(NSError *)error;

+ (void)error:(UIViewController *)viewController
        title:(NSString *)title
        error:(NSError *)error
   completion:(void (^)(void))completion;

+ (void)warn:(UIViewController *)viewController
       title:(NSString *)title
     message:(NSString *)message;

+ (void)  warn:(UIViewController *)viewController
         title:(NSString *)title
       message:(NSString *)message
    completion:(void (^)(void))completion;

+ (void)info:(UIViewController *)viewController
       title:(NSString *)title
     message:(NSString *)message;


+ (void)  info:(UIViewController *)viewController
         title:(NSString *)title
       message:(NSString *)message
    completion:(void (^)(void))completion;

+ (void)   twoOptionsWithCancel:(UIViewController *)viewController
                    title:(NSString *)title
                  message:(NSString *)message
        defaultButtonText:(NSString *)defaultButtonText
         secondButtonText:(NSString *)secondButtonText
                   action:(void (^) (int response))action;

+ (void)   twoOptions:(UIViewController *)viewController
                title:(NSString *)title
              message:(NSString *)message
    defaultButtonText:(NSString *)defaultButtonText
     secondButtonText:(NSString *)secondButtonText
               action:(void (^)(BOOL response))action;

+ (void) threeOptions:(UIViewController *)viewController
                title:(NSString *)title
              message:(NSString *)message
    defaultButtonText:(NSString *)defaultButtonText
     secondButtonText:(NSString *)secondButtonText
      thirdButtonText:(NSString *)thirdButtonText
               action:(void (^)(int response))action;

+ (void) threeOptionsWithCancel:(UIViewController *)viewController
                          title:(NSString *)title
                        message:(NSString *)message
              defaultButtonText:(NSString *)defaultButtonText
               secondButtonText:(NSString *)secondButtonText
                thirdButtonText:(NSString *)thirdButtonText
                         action:(void (^) (int response))action;

+ (void)OkCancelWithPassword:(UIViewController *)viewController
                       title:(NSString *)title
                     message:(NSString *)message
                  completion:(void (^)(NSString *password, BOOL response))completion;

+ (void)OkCancelWithTextField:(UIViewController *)viewController
                textFieldText:(NSString *)textFieldText
                        title:(NSString *)title
                      message:(NSString *)message
                   completion:(void (^) (NSString *text, BOOL response))completion;

+ (void)OkCancelWithTextField:(UIViewController *)viewController
         textFieldPlaceHolder:(NSString *)textFieldPlaceHolder
                        title:(NSString *)title
                      message:(NSString *)message
                   completion:(void (^)(NSString *text, BOOL response))completion;

+ (void)actionSheet:(UIViewController *)viewController
          barButton:(UIBarButtonItem *)barButton
              title:(NSString *)title
       buttonTitles:(NSArray<NSString *> *)buttonTitles
         completion:(void (^)(int response))completion;

+ (void)actionSheet:(UIViewController *)viewController
               rect:(CGRect)rect
              title:(NSString *)title
       buttonTitles:(NSArray<NSString *> *)buttonTitles
         completion:(void (^)(int response))completion;

- (void)OkCancelWithTextFieldNotEmpty:(UIViewController *)viewController
                        textFieldText:(NSString *)textFieldText
                           completion:(void (^) (NSString *text, BOOL response))completion;

- (void)OkCancelWithPasswordNonEmpty:(UIViewController *)viewController
                          completion:(void (^) (NSString *password, BOOL response))completion;

@end
