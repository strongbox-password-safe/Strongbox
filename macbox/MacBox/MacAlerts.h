//
//  Alerts.h
//  MacBox
//
//  Created by Mark on 11/08/2017.
//  Copyright © 2017 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <Cocoa/Cocoa.h>

@interface MacAlerts : NSObject<NSTextFieldDelegate>

+ (void)error:(const NSError*)error window:(NSWindow*)window;
+ (void)error:(const NSError*)error window:(NSWindow*)window completion:(void (^)(void))completion;

+ (void)error:(NSString*)message error:(const NSError*)error window:(NSWindow*)window;
+ (void)error:(NSString*)message error:(const NSError*)error window:(NSWindow*)window completion:(void (^)(void))completion;

+ (void)info:(NSString *)info window:(NSWindow*)window;
+ (void)info:(NSString *)message informativeText:(NSString*)informativeText window:(NSWindow*)window completion:(void (^)(void))completion;

+ (void)areYouSure:(NSString*)message window:(NSWindow*)window completion:(void (^) (BOOL response))completion;

+ (void)yesNo:(NSString *)info window:(NSWindow*)window completion:(void (^)(BOOL yesNo))completion;
+ (void)yesNo:(NSString *)messageText informativeText:(NSString*)informativeText window:(NSWindow*)window completion:(void (^)(BOOL yesNo))completion;

+ (void)yesNo:(NSString *)messageText
informativeText:(NSString*)informativeText
       window:(NSWindow*)window
disableEscapeKey:(BOOL)disableEscapeKey
   completion:(void (^)(BOOL yesNo))completion;

+ (void)twoOptions:(NSString *)messageText
   informativeText:(NSString*)informativeText
 option1AndDefault:(NSString*)option1AndDefault
           option2:(NSString*)option2
            window:(NSWindow*)window
        completion:(void (^)(NSUInteger option))completion;

+ (void)threeOptions:(NSString *)messageText
     informativeText:(NSString*)informativeText
   option1AndDefault:(NSString*)option1AndDefault
             option2:(NSString*)option2
             option3:(NSString*)option3
              window:(NSWindow*)window
          completion:(void (^)(NSUInteger option))completion;

+ (void)threeOptionsWithCancel:(NSString *)messageText
               informativeText:(NSString *)informativeText
             option1AndDefault:(NSString *)option1AndDefault
                       option2:(NSString *)option2
                       option3:(NSString *)option3
                        window:(NSWindow *)window
                    completion:(void (^)(NSUInteger))completion;

+ (void)twoOptionsWithCancel:(NSString *)messageText
             informativeText:(NSString*)informativeText
           option1AndDefault:(NSString*)option1AndDefault
                     option2:(NSString*)option2
                      window:(NSWindow*)window
                  completion:(void (^)(int response))completion;

+ (void)customOptionWithCancel:(NSString *)messageText
               informativeText:(NSString*)informativeText
             option1AndDefault:(NSString*)option1AndDefault
                        window:(NSWindow*)window
                    completion:(void (^)(BOOL go))completion;

- (NSString *)input:(NSString *)prompt defaultValue:(NSString *)defaultValue allowEmpty:(BOOL)allowEmpty;
- (NSString *)input:(NSString *)prompt defaultValue:(NSString *)defaultValue allowEmpty:(BOOL)allowEmpty secure:(BOOL)secure;

- (void)inputKeyValue:(NSString*)prompt
              initKey:(NSString*)initKey
            initValue:(NSString*)initValue
        initProtected:(BOOL)initProtected
          placeHolder:(BOOL)placeHolder
           completion:(void (^)(BOOL yesNo, NSString* key, NSString* value, BOOL protected))completion;

@end
