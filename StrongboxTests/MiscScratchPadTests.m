//
//  MiscScratchPadTests.m
//  StrongboxTests
//
//  Created by Mark on 27/10/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "OfflineCacheNameDetector.h"

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

- (void)testNickNameMatchesOldOfflineCacheWithEmpty {
    BOOL result = [OfflineCacheNameDetector nickNameMatchesOldOfflineCache:@""];

    XCTAssertFalse(result);
}

- (void)testNickNameMatchesOldOfflineCacheWithPlausibleName {
    BOOL result = [OfflineCacheNameDetector nickNameMatchesOldOfflineCache:@"Default"];
    
    XCTAssertFalse(result);
}

- (void)testNickNameMatchesOldOfflineCacheWithPlausibleName2 {
    BOOL result = [OfflineCacheNameDetector nickNameMatchesOldOfflineCache:@"My First Safe"];
    
    XCTAssertFalse(result);
}

- (void)testNickNameMatchesOldOfflineCacheWithPlausibleName3 {
    BOOL result = [OfflineCacheNameDetector nickNameMatchesOldOfflineCache:@"Mark's Safe"];
    
    XCTAssertFalse(result);
}

- (void)testNickNameDoesNotMatchOneOff {
    NSString* nickName = @"D6038A2B-8B6F-4CB5-A524-339A31DBB59A-strongbox-offline-cach";
    
    NSLog(@"%ld", nickName.length);
    
    BOOL result = [OfflineCacheNameDetector nickNameMatchesOldOfflineCache:nickName];
    
    XCTAssertFalse(result);
}

- (void)testNickNameDoesNotMatchOffByOne {
    NSString* nickName = @"D6038A2B-8B6F-4CB5-A524-339A31DBB59A-strongbox-offline-cachf";
    
    NSLog(@"%ld", nickName.length);
    
    BOOL result = [OfflineCacheNameDetector nickNameMatchesOldOfflineCache:nickName];
    
    XCTAssertFalse(result);
}

- (void)testNickNameMatchesOfflineCacheNickName {
    NSString* nickName = @"D6038A2B-8B6F-4CB5-A524-339A31DBB59A-strongbox-offline-cache";
    
    NSLog(@"%ld", nickName.length);
    
    BOOL result = [OfflineCacheNameDetector nickNameMatchesOldOfflineCache:nickName];
    
    XCTAssertTrue(result);
}

@end
