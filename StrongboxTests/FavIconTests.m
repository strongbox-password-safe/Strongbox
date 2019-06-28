//
//  FavIconTests.m
//  StrongboxTests
//
//  Created by Mark on 28/06/2019.
//  Copyright © 2019 Mark McGuill. All rights reserved.
//

#import <XCTest/XCTest.h>

@import FavIcon;

static const int kMaxRecommendedCustomIconDimension = 256;

@interface FavIconTests : XCTestCase

@property BOOL done;

@end

@implementation FavIconTests

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
    
    [FavIcon downloadPreferred:url
                        width:kMaxRecommendedCustomIconDimension
                       height:kMaxRecommendedCustomIconDimension
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
