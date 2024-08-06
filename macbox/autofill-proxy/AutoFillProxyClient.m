//
//  AutoFillProxyClient.m
//  MacBox
//
//  Created by Strongbox on 15/08/2022.
//  Copyright © 2022 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "AutoFillProxy.h"
#import <Cocoa/Cocoa.h>

#import <signal.h>
#include <sys/types.h>
#include <netinet/in.h>
#import <sys/socket.h>
#import <sys/un.h>
#include <errno.h>

#import "NSString+Extensions.h"
#import "SBLog.h"

static const int kMaxResponseLength = 1024*1024; 

void onGotBrowserExtensionMessage(NSData* data);
void decodeBrowserExtensionMessage(void);

NSString* jsonErrorMessage(NSString* message);
NSString* jsonMessage(BOOL success, NSString* message);
NSString* jsonResponseOK(void);

BOOL isLaunchStrongboxMessage(NSString* str, NSString** initiateUnlockDatabaseUuid);
BOOL launchStrongbox(NSString* _Nullable initiateUnlockDatabaseUuid, NSError** error);

void sigHandler(int sig) {
    exit(1);
}

int main(int argc, const char * argv[]) {
    signal(SIGQUIT, sigHandler);
    signal(SIGINT, sigHandler);
    signal(SIGTERM, sigHandler);
    signal(SIGHUP, sigHandler);

    @autoreleasepool {
        slog(@"✅ Strongbox AutoFill Proxy is Alive...");

        for ( int i=0;i<argc;i++) {
            slog(@"ARG %d: [%s]", i, argv[i]);
        }

        
        
        decodeBrowserExtensionMessage();

        slog(@"✅ Strongbox AutoFill Proxy is Exiting...");
    }
}

void decodeBrowserExtensionMessage(void) {
    NSFileHandle *stdIn = NSFileHandle.fileHandleWithStandardInput;

    NSError * stdinError = nil;
    NSData * rawReqLen = [stdIn readDataUpToLength:4 error:&stdinError];
    
    if(rawReqLen == nil || stdinError != nil) {
        slog(@"🔴 Could not read STDIN length: [%@]", stdinError);
        exit(1);
    }
    
    uint32_t reqLen;
    [rawReqLen getBytes:&reqLen length:4];
    reqLen = OSSwapLittleToHostInt32(reqLen);
    
    NSData * req = [stdIn readDataUpToLength:reqLen error:&stdinError];
    
    if(req == nil || stdinError != nil) {
        slog(@"🔴 Could not read STDIN: [%@]", stdinError);
        exit(1);
    }
    
    if ( req.length == 0 ) {
        slog(@"⚠️ Zero Length STDIN Notify?");
        return;
    }
    
    onGotBrowserExtensionMessage(req);
}

void onGotBrowserExtensionMessage(NSData* data) {
    NSString* str = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];

    
    
    NSError* error;
    NSString *message = sendMessageOverSocket(str, NO, &error);

    if ( message == nil ) {
        NSString* initiateUnlockDatabaseUuid = nil;
        if ( isLaunchStrongboxMessage(str, &initiateUnlockDatabaseUuid) ) {
            if ( launchStrongbox( initiateUnlockDatabaseUuid, &error ) ) {
                message = jsonResponseOK();
            }
            else {
                message = jsonErrorMessage(error.localizedDescription);
            }
        }
        else {
            message = jsonErrorMessage(error.localizedDescription);
        }
    }
    
    NSUInteger len = message.length;
    slog(@"Got Response from main Strongbox APP of length [%lu]:\n%@\n", len, message);
    
    
    
    if ( [message containsString:@"🔴"] || [message containsString:@"✅"] || [message containsString:@"⚠️"] ) {
        slog(@"🔴 Response contains an emoji which will crash Chrome! Not sending.");
        message = jsonErrorMessage(@"🔴 Response contains an emoji which will crash Chrome! Not sending.");
        len = message.length;
    }
    
    
    
    if ( len > kMaxResponseLength ) {
        slog(@"🔴 Response length is greater than NativeMessaging limit of 1MB. Cannot respond.");
        message = jsonErrorMessage(@"Response length is greater than NativeMessaging limit of 1MB. Cannot respond.");
        len = message.length;
    }
    
    NSData* dataLen = [NSData dataWithBytes:&len length:4];
    NSData* messageData = [message dataUsingEncoding:NSUTF8StringEncoding];
    [NSFileHandle.fileHandleWithStandardOutput writeData:dataLen];
    [NSFileHandle.fileHandleWithStandardOutput writeData:messageData];
}

BOOL isLaunchStrongboxMessage(NSString* str, NSString** initiateUnlockDatabaseUuid) {
    NSError* error;
    id object = [NSJSONSerialization JSONObjectWithData:str.utf8Data options:kNilOptions error:&error];

    if ( object && [object isKindOfClass:NSDictionary.class] ) {
        NSDictionary* dict = (NSDictionary*)object;
        
        if ( dict[@"launch"] != nil ) {
            *initiateUnlockDatabaseUuid = dict[@"initiateUnlockDatabaseUuid"];
            return YES;
        }
    }
    
    return NO;
}

BOOL launchStrongbox(NSString* _Nullable initiateUnlockDatabaseUuid, NSError** error) {
    
    NSString* pathToStrongbox =  NSBundle.mainBundle.bundlePath  ; 

    slog(@"✅ Launch Strongbox at: [%@]", pathToStrongbox);

    
    if ( pathToStrongbox.length ) {
        NSWorkspaceOpenConfiguration* config = [NSWorkspaceOpenConfiguration configuration];

        
        
        
        
        
        
        
        
        
        
        
        config.hides = YES; 
        NSURL* url = [NSURL fileURLWithPath:pathToStrongbox];
        
        __block BOOL ret;
        dispatch_group_t g = dispatch_group_create();
        dispatch_group_enter(g);

        [NSWorkspace.sharedWorkspace openApplicationAtURL:url
                                            configuration:config
                                        completionHandler:^(NSRunningApplication * _Nullable app, NSError * _Nullable error) {

            ret = error == nil;
            dispatch_group_leave(g);
        }];
        
        dispatch_group_wait(g, DISPATCH_TIME_FOREVER);
        
        slog(@"✅ Launch Done! ret = [%hhd]", ret);
        
        return ret;
    }
    
    return NO;
}

NSString* jsonErrorMessage(NSString* message) {
    return jsonMessage(NO, message);
}

NSString* jsonResponseOK(void) {
    return jsonMessage(YES, nil);
}

NSString* jsonMessage(BOOL success, NSString* message) {
    NSMutableDictionary *dict = @{ @"success" : @(success) }.mutableCopy;
    
    if ( message ) {
        dict[@"error"] = message;
    }
    
    NSError* error;
    NSData* data = [NSJSONSerialization dataWithJSONObject:dict options:kNilOptions error:&error];
    if ( !data || error ) {
        slog(@"Could not create JSON for message: [%@] - error = [%@]", message, error);
        return @"{ \"error\" : \"unknown\" }";
    }
    
    NSString* str = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    
    return str;
}

