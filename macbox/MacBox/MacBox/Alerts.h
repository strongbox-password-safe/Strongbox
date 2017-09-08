//
//  Alerts.h
//  MacBox
//
//  Created by Mark on 11/08/2017.
//  Copyright © 2017 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <Cocoa/Cocoa.h>

@interface Alerts : NSObject

+ (void)error:(NSError*)error window:(NSWindow*)window;
+ (void)error:(NSString*)message error:(NSError*)error window:(NSWindow*)window;
+ (void)error:(NSString*)message error:(NSError*)error window:(NSWindow*)window completion:(void (^)(void))completion;

+ (void)info:(NSString *)info window:(NSWindow*)window;
+ (void)info:(NSString *)message informativeText:(NSString*)informativeText window:(NSWindow*)window completion:(void (^)(void))completion;

+ (void)yesNo:(NSString *)info window:(NSWindow*)window completion:(void (^)(BOOL yesNo))completion;

@end
