//
//  MiscScratchPadTests.m
//  StrongboxTests
//
//  Created by Mark on 27/10/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
//

#import <XCTest/XCTest.h>

@interface MiscScratchPadTests : XCTestCase

@end

@implementation MiscScratchPadTests

- (void)testEmptyBase64StringData {
    NSData* ret = [[NSData alloc] initWithBase64EncodedString:@"" options:kNilOptions];

    XCTAssertNotNil(ret);
    XCTAssert(ret.length == 0);
}

- (void)testNilBase64StringData {
    NSData* ret = [[NSData alloc] initWithBase64EncodedString:@"" options:kNilOptions];
    
    XCTAssertNotNil(ret);
    XCTAssert(ret.length == 0);
}

@end
