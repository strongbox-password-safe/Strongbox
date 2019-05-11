//
//  OfflineDetector.m
//  Strongbox-iOS
//
//  Created by Mark on 11/10/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
//

#import "OfflineDetector.h"
#import "Reachability.h"

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
    [self.internetReachabilityDetector stopNotifier];
    self.internetReachabilityDetector = nil;
    self.offline = NO;
}
    
- (void) startMonitoringConnectivitity {
    self.offline = NO;

    self.internetReachabilityDetector = [Reachability reachabilityWithHostname:@"www.google.com"];
    
    // Internet is reachable
    
    __weak typeof(self) weakSelf = self;
    self.internetReachabilityDetector.reachableBlock = ^(Reachability *reach)
    {
        NSLog(@"OfflineDetector: We Are Online :)");
        weakSelf.offline = NO;
    };
    
    // Internet is not reachable
    
    self.internetReachabilityDetector.unreachableBlock = ^(Reachability *reach)
    {
        NSLog(@"OfflineDetector: We Are Offline :(");
        weakSelf.offline = YES;
    };
    
    [self.internetReachabilityDetector startNotifier];
}

- (BOOL) isOffline {
    return self.offline;
}

@end
