//
//  AlertingUI.h
//  MacBox
//
//  Created by Strongbox on 31/10/2021.
//  Copyright © 2021 Mark McGuill. All rights reserved.
//

#ifndef AlertingUI_h
#define AlertingUI_h

#if TARGET_OS_IPHONE

#import <UIKit/UIKit.h>

typedef UIViewController* PARENT_UI_ELEMENT_PTR;

#else

#import <Cocoa/Cocoa.h>

typedef NSViewController* PARENT_UI_ELEMENT_PTR;

#endif

NS_ASSUME_NONNULL_BEGIN

@protocol AlertingUI <NSObject>

- (void)error:(PARENT_UI_ELEMENT_PTR)parentUiElement
        error:(const NSError *)error
   completion:(void (^)(void))completion;

- (void)error:(PARENT_UI_ELEMENT_PTR)parentUiElement
        title:(NSString *)title
        error:(const NSError *)error
   completion:(void (^)(void))completion;

- (void)  warn:(PARENT_UI_ELEMENT_PTR)parentUiElement
         title:(NSString *)title
       message:(NSString *)message
    completion:(void (^)(void))completion;

- (void)   twoOptionsWithCancel:(PARENT_UI_ELEMENT_PTR)parentUiElement
                          title:(NSString *)title
                        message:(NSString *)message
              defaultButtonText:(NSString *)defaultButtonText
               secondButtonText:(NSString *)secondButtonText
                         action:(void (^)(int response))action;

- (void)warn:(PARENT_UI_ELEMENT_PTR)parentUiElement
       title:(NSString *)title
     message:(NSString *)message;

- (void)  info:(PARENT_UI_ELEMENT_PTR)parentUiElement
         title:(NSString *)title
       message:(NSString *)message
    completion:(void (^ _Nullable)(void))completion;

- (void)areYouSure:(PARENT_UI_ELEMENT_PTR)parentUiElement message:(NSString*)message action:(void (^) (BOOL response))action;

@end

NS_ASSUME_NONNULL_END

#endif /* AlertingUI_h */
