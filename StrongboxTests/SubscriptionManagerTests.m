//
//  SubscriptionManagerTests.m
//  StrongboxTests
//
//  Created by Mark on 04/02/2019.
//  Copyright © 2019 Mark McGuill. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "SubscriptionManager.h"

@interface SubscriptionManagerTests : XCTestCase

@property BOOL done;

@end

@implementation SubscriptionManagerTests

- (void)testGetAvailableSubscriptions {
    SubscriptionManager* mgr =  [[SubscriptionManager alloc] init];
    
    [mgr getAvailableSubscriptions:^(NSError * _Nonnull error, NSArray<SubscriptionOption *> * _Nonnull options) {
        NSLog(@"completion: %@-[%@]", error, options);
        self.done = YES;
    }];
    
    [self waitUntilDone];
}

- (void)testCreatePayment {
    SubscriptionManager* mgr =  [[SubscriptionManager alloc] init];
    
    [mgr getAvailableSubscriptions:^(NSError * _Nonnull error, NSArray<SubscriptionOption *> * _Nonnull options) {
        NSLog(@"completion: %@-[%@]", error, options);

        XCTAssert(options.count > 0);
        
        SubscriptionOption* first = [options firstObject];
        [mgr purchase:first];
        
        self.done = YES;
    }];
    
    [self waitUntilDone];
}

- (void)waitUntilDone {
    while(!self.done) {
        //[[NSRunLoop currentRunLoop] runUntilDate:[[NSDate date] dateByAddingTimeInterval:4]]; // 4 seconds
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate distantFuture]];
    }
}

@end
