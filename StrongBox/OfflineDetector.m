//
//  OfflineDetector.m
//  Strongbox-iOS
//
//  Created by Mark on 11/10/2018.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import "OfflineDetector.h"
#import "Reachability.h"
#import "AppPreferences.h"

@interface OfflineDetector ()

@property (nonatomic, strong) Reachability *internetReachabilityDetector;
@property (nonatomic) BOOL offline; // Global Online/Offline variable
    
@end

@implementation OfflineDetector

+ (instancetype)sharedInstance {
    static OfflineDetector *sharedInstance = nil;
    static dispatch_once_t onceToken;
    
    dispatch_once(&onceToken, ^{
        sharedInstance = [[OfflineDetector alloc] init];
    });
    
    return sharedInstance;
}

- (void) stopMonitoringConnectivitity {
    NSLog(@"STOP monitoring Internet Connectivity...");
    
    
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.internetReachabilityDetector stopNotifier];
        self.internetReachabilityDetector = nil;
        self.offline = NO;
    });
}
    
- (void) startMonitoringConnectivitity {
    if (!AppPreferences.sharedInstance.monitorInternetConnectivity) {
        NSLog(@"Not monitoring connectivity as configured OFF");
        return;
    }
   
    if ( !self.internetReachabilityDetector ) { 
        self.offline = NO;
    }
    
    self.internetReachabilityDetector = [Reachability reachabilityWithHostname:@"duckduckgo.com"];
    
    
    
    __weak typeof(self) weakSelf = self;
    self.internetReachabilityDetector.reachableBlock = ^(Reachability *reach)
    {

        weakSelf.offline = NO;
    };
    
    
    
    self.internetReachabilityDetector.unreachableBlock = ^(Reachability *reach)
    {
        NSLog(@"OfflineDetector: We Are Offline :(");
        weakSelf.offline = YES;
    };


    dispatch_async(dispatch_get_main_queue(), ^{
        [self.internetReachabilityDetector startNotifier];
    });
}

- (BOOL) isOffline {
    return self.offline;
}

@end
