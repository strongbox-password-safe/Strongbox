//
//  main.m
//  MacBox
//
//  Created by Mark on 01/08/2017.
//  Copyright © 2017 Mark McGuill. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "SBLog.h"

void sigHandler(int sig) {
    slog(@"⚠️ Caught Signal: %d Going to ignore... AutoFillProxy failed to write, no one on other end.", sig);
    
    // e.g. Initiate an unlock from the browser, then ignore it, and it will wait until timeout, but if the extension makes another request, it somehow causes the first request to die and this previous killed Strongbox outright!
}

int main(int argc, const char * argv[]) {
    signal (SIGPIPE, sigHandler); 
    

    
    return NSApplicationMain(argc, argv);
}
