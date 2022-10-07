//
//  AutoFillProxyTestClient.m
//  afproxy-debug-harness
//
//  Created by Strongbox on 16/08/2022.
//  Copyright © 2022 Mark McGuill. All rights reserved.
//


#import <Foundation/Foundation.h>
#import "AutoFillProxy.h"

#include "stdio.h"

#import <signal.h>
#include <sys/types.h>
#include <netinet/in.h>
#import <sys/socket.h>
#import <sys/un.h>
#include <errno.h>

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        NSLog(@"✅ Strongbox AutoFill Test Client is Alive...");
        NSLog(@"%s", argv[0]);

        while ( YES ) {

            NSString* request = @"{\"clientPublicKey\":\"foo\",\"messageSymmetricKey\":\"bar\",\"message\":\"message\",\"messageType\":1}";
            
            NSLog(@"Sending... [%@]", request);
            
            NSString* response = sendMessageOverSocket(request, YES);
            
            NSLog(@"Got response => \n%@\n", response);

            int ch = getchar();
            
            if ( ch == '1' ) {
                break;
            }
            else {
                NSLog(@"Got Char = %d", ch);
            }
        }
        
        NSLog(@"✅ Strongbox AutoFill Proxy is Exiting...");

        return 0;
    }
}
