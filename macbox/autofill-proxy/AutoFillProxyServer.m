//
//  AutoFillProxyServer.m
//  MacBox
//
//  Created by Strongbox on 14/08/2022.
//  Copyright © 2022 Mark McGuill. All rights reserved.
//

#import "AutoFillProxyServer.h"
#import "AutoFillProxy.h"
#import "StreamUtils.h"
#include <sys/types.h>
#include <netinet/in.h>
#include <sys/socket.h>
#include <sys/un.h>
#include <errno.h>
#import "Strongbox-Swift.h"
#import "NSArray+Extensions.h"

@interface AutoFillProxyServer ()

@property int server_sock;

@end

@implementation AutoFillProxyServer

+ (instancetype)sharedInstance {
    static AutoFillProxyServer *sharedInstance = nil;
    static dispatch_once_t onceToken;
    
    dispatch_once(&onceToken, ^{
        sharedInstance = [[AutoFillProxyServer alloc] init];
    });
    
    return sharedInstance;
}

- (void)stop {


    if ( !self.isRunning ) {
        return;
    }
    

    
    if ( self.server_sock != -1 ) {
        shutdown(self.server_sock, SHUT_RDWR);
        close(self.server_sock);
        self.server_sock = -1;
    }
    

    

    
    _isRunning = NO;
}

- (BOOL)start {


    if ( self.isRunning ) {
        return YES;
    }
    
    NSString* path = getSocketPath(NO);
    if ( !path ) {
        slog(@"🔴 Path too long for getSocketPath - Check users home dir");
        return NO;
    }

    struct sockaddr_un sun;
    sun.sun_family = AF_UNIX;
    strcpy (sun.sun_path, [path cStringUsingEncoding:NSUTF8StringEncoding]);
    sun.sun_len = SUN_LEN(&sun);
    
    if (unlink(sun.sun_path) == -1) {
        if ( errno != ENOENT ) {
            slog(@"⚠️ unlink: %s\n,%d", strerror(errno), errno);
        }
    }

    self.server_sock = socket (AF_UNIX, SOCK_STREAM, 0);
    if ( self.server_sock == -1 ) {
        slog(@"🔴 Error creating socket: %s\n", strerror(errno));
        return NO;
    }
    
    const int kBufferSize = 2 * 1024 * 1024; 
    if (setsockopt(self.server_sock, SOL_SOCKET, SO_RCVBUF, &kBufferSize, sizeof(int)) == -1) {
        slog(@"🔴 Error setting socket SO_RCVBUF opts: %s\n", strerror(errno));
        return NO;
    }
    if (setsockopt(self.server_sock, SOL_SOCKET, SO_SNDBUF, &kBufferSize, sizeof(int)) == -1) {
        slog(@"🔴 Error setting socket SO_SNDBUF opts: %s\n", strerror(errno));
        return NO;
    }

    
    
    
    if (unlink(sun.sun_path) == -1) {
        if ( errno != ENOENT) {
            slog(@"⚠️ unlink: %s\n,%d", strerror(errno), errno);
        }
    }

    int ret = bind (self.server_sock, (struct sockaddr *)&sun, sun.sun_len);
    if ( ret < 0 ) {
        slog(@"🔴 bind failed. %s", strerror(errno));
        return NO;
    }
    
    int listenResult = listen (self.server_sock, SOMAXCONN);
    if ( listenResult == -1 ) {
        slog(@"🔴 Error listening on socket: %s\n", strerror(errno));
        return NO;
    }

    [NSThread detachNewThreadWithBlock:^{
        [self acceptNewConnections];
    }];



    _isRunning = YES;
    return YES; 
}

- (void)acceptNewConnections {
    while ( 1 ) {


        int socket = accept (self.server_sock, NULL, NULL);

        if ( socket == -1 ) {
            slog(@"⚠️ AutoFillProxyServer failed to accept new connection (possibly due to shutdown...) - %s", strerror(errno));
            break;
        }
        


        
        

            [self handleNewConnection:socket];

    }
    

}

- (void)handleNewConnection:(int)socket {
    

#ifdef DEBUG
    NSTimeInterval startTime = NSDate.timeIntervalSinceReferenceDate;
#endif

    CFReadStreamRef readStream;
    CFWriteStreamRef writeStream;
    CFStreamCreatePairWithSocket (kCFAllocatorDefault, socket, &readStream, &writeStream);

    NSInputStream *inputStream = (__bridge_transfer NSInputStream *)readStream;
    
    [inputStream open];
    
    NSString* jsonRequest = readJsonObjectFromInputStream(inputStream, YES);
    
    [inputStream close];
    
    if ( !jsonRequest ) {
        
        slog(@"🔴 Could not read valid JSON object! Connection done.");
        shutdown(socket, SHUT_RDWR);
        close(socket);
        return;
    }
    
    
        
    NSString* jsonResponse = [AutoFillRequestHandler.shared handleJsonRequestWithJson:jsonRequest];
    
    
    
    
    
    NSOutputStream *outputStream = (__bridge_transfer NSOutputStream *)writeStream;

    [outputStream open];

    NSData* msg = [jsonResponse dataUsingEncoding:NSUTF8StringEncoding];
    
    
    NSUInteger len = msg.length;
    
    [outputStream write:msg.bytes maxLength:len];
    [outputStream close];
    
    shutdown(socket, SHUT_RDWR);
    close(socket);
    
#ifdef DEBUG
    if ( len > 10 * 1024 ) {
        slog(@"🐞 Writing LARGE JSON Response of length [%lu] in %f seconds", len, NSDate.timeIntervalSinceReferenceDate - startTime);
    }
#endif
    
}

@end
