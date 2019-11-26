//
//  FavIconTests.m
//  StrongboxTests
//
//  Created by Mark on 28/06/2019.
//  Copyright © 2019 Mark McGuill. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "FavIconManager.h"

@interface FavIconTests : XCTestCase

@property BOOL done;

@end

@implementation FavIconTests

- (void)testMultiple {
    NSArray<NSURL*>* urls = @[
        [NSURL URLWithString:@"https://nasa.gov"],
        [NSURL URLWithString:@"https://google.com"],
        [NSURL URLWithString:@"https://microsoft.com"],
    ];
    
    NSOperationQueue* queue = [NSOperationQueue new];
    queue.maxConcurrentOperationCount = 8;

    // TODO: Cancellable... ?

    NSMutableDictionary<NSURL*, UIImage*>* results = [NSMutableDictionary dictionary];

    __block NSUInteger doneCount = 0;
    [FavIconManager.sharedInstance getFavIconsForUrls:urls
                                                queue:queue
                                         withProgress:^(NSURL * url, UIImage * _Nullable image) {
        NSLog(@"Got %@ => %@ - %lu", url, image, (unsigned long)doneCount);
        results[url] = image;
      
        doneCount++;
        
        if(doneCount == urls.count) {
            //
        }
    }];
    
    /////////////////////////////////////////////////////////////////////////////////////
    // Do not wait on main thread! -> Notifications are sent there - do not block...
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0L), ^{
        [queue waitUntilAllOperationsAreFinished];
        self.done = YES;
    });

    [self waitUntilDone];
}

- (void)testExample1 {
    [self tryGetFavIcon:@"https://www.adac.de/"];
}

- (void)testExample2 {
    [self tryGetFavIcon:@"https://www.shell.de"];
}

- (void)testExample3 {
    [self tryGetFavIcon:@"https://www.trendnet.com"];
}

- (void)testExample4 {
    [self tryGetFavIcon:@"https://www.ups.com"];
}

- (void)tryGetFavIcon:(NSString*)str {
    NSURL *url = [NSURL URLWithString:str];
    
    [FavIconManager.sharedInstance downloadPreferred:url
                                          completion:^(UIImage * _Nullable image) {
        NSLog(@"%@", image);
                        
        XCTAssert(image && image.size.width > 0 && image.size.height > 0);
        
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
