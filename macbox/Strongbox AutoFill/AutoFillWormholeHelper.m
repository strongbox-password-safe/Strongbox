//
//  AutoFillWormholeHelper.m
//  MacBox
//
//  Created by Strongbox on 19/10/2023.
//  Copyright © 2023 Mark McGuill. All rights reserved.
//

#import "AutoFillWormholeHelper.h"
#import "MMWormhole.h"
#import "Settings.h"
#import "AutoFillWormhole.h"
#import "QuickTypeRecordIdentifier.h"
#import "NSArray+Extensions.h"

#import "DatabasesManager.h"

#ifndef IS_APP_EXTENSION
#import "Strongbox-Swift.h"
#else
#import "Strongbox_Auto_Fill-Swift.h"
#endif

static const CGFloat kWormholeWaitTimeout = 0.4f; 

@interface AutoFillWormholeHelper ()

@property MMWormhole* wormhole;

@end

@implementation AutoFillWormholeHelper

+ (instancetype)sharedInstance {
    static AutoFillWormholeHelper *sharedInstance = nil;
    static dispatch_once_t onceToken;
    
    dispatch_once(&onceToken, ^{
        sharedInstance = [[AutoFillWormholeHelper alloc] init];
    });
    
    return sharedInstance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        self.wormhole = [[MMWormhole alloc] initWithApplicationGroupIdentifier:Settings.sharedInstance.appGroupName
                                                             optionalDirectory:kAutoFillWormholeName];
        



    }
    
    return self;
}

- (void)cleanupWormhole {
    slog(@"✅ cleanupWormhole");
    
    if ( self.wormhole ) {
        slog(@"Cleaning up wormhole...");
        [self.wormhole clearAllMessageContents];
        self.wormhole = nil; 
    }
}






- (void)postWormholeMessage:(NSString *)requestId 
                 responseId:(NSString *)responseId
                    message:(NSDictionary<NSString *,id> *)message
                 completion:(void (^)(BOOL, NSDictionary<NSString *,id> * _Nullable))completion {
    [self postWormholeMessage:requestId responseId:responseId message:message timeout:kWormholeWaitTimeout completion:completion];
}

- (void)postWormholeMessage:(NSString*)requestId
                 responseId:(NSString*)responseId
                    message:(NSDictionary<NSString*, id>*)message
                    timeout:(CGFloat)timeout
                 completion:(void (^ _Nullable)(BOOL success, NSDictionary<NSString*, id>* _Nullable response))completion {

    
    [self.wormhole passMessageObject:message identifier:requestId];
    
    __block BOOL gotResponse = NO;
    dispatch_group_t group = dispatch_group_create();
    dispatch_group_enter(group);
    
    NSTimeInterval start = NSDate.timeIntervalSinceReferenceDate;
    
    [self.wormhole listenForMessageWithIdentifier:responseId
                                         listener:^(id messageObject) {
        if (!gotResponse) {
            gotResponse = YES;
            [self.wormhole stopListeningForMessageWithIdentifier:responseId];
            [self.wormhole clearMessageContentsForIdentifier:responseId];
        }
        else {
            slog(@"🔴 Ignoring Duplicated Response from Wormhole"); 
            return;
        }
        

        
        dispatch_async(dispatch_get_main_queue(), ^{
            NSMutableDictionary<NSString*, id>* response = ((NSDictionary*)messageObject).mutableCopy;
            BOOL messageSuccess = response[@"success"] && ((NSNumber*)response[@"success"]).boolValue;
            [response removeObjectForKey:@"success"];
            
            if ( completion ) {
                completion(messageSuccess, response);
            }
        });
    }];
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0L), ^{
        intptr_t disp = dispatch_group_wait(group, dispatch_time(DISPATCH_TIME_NOW, timeout * NSEC_PER_SEC));
        
        NSTimeInterval interval = NSDate.timeIntervalSinceReferenceDate - start;
        
        if ( !gotResponse ) {
            slog(@"🟢 ⚠️ AUTOFILL-WORMHOLE - Did Not Get Response in [%f] seconds - disp = %ld", interval, disp);
            
            [self.wormhole stopListeningForMessageWithIdentifier:responseId];
            [self.wormhole clearMessageContentsForIdentifier:responseId];
            
            dispatch_async(dispatch_get_main_queue(), ^{
                if ( completion ) {
                    completion(NO, nil);
                }
            });
        }
    });
}

@end
