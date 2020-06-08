//
//  CyrillicUrlTests.m
//  StrongboxTests
//
//  Created by Strongbox on 05/06/2020.
//  Copyright © 2020 Mark McGuill. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "NSString+Extensions.h"

@interface CyrillicUrlTests : XCTestCase

@end

@implementation CyrillicUrlTests

- (void)testEmpty {
    NSString* unc = @"";
    NSURL* url = unc.mmcgUrl;
    NSLog(@"url = [%@]", url);

    XCTAssertNil(url);
}

- (void)testCyrillicNoPath {
    NSString* unc = @"https://честныйзнак.рф";
    NSURL* url = unc.mmcgUrl;
    NSLog(@"url = [%@]", url);

    BOOL ret =[UIApplication.sharedApplication canOpenURL:url];

    XCTAssertNotNil(url);
    XCTAssertTrue(ret);
}

- (void)testCyrillic {
    NSString* unc = @"https://честныйзнак.рф/";
    NSURL* url = unc.mmcgUrl;
    NSLog(@"url = [%@]", url);

    BOOL ret =[UIApplication.sharedApplication canOpenURL:url];

    XCTAssertNotNil(url);
    XCTAssertTrue(ret);
}

- (void)testCyrillic2 {
    NSString* unc = @"http://мфц-омск.рф/";
    NSURL* url = unc.mmcgUrl;
    NSLog(@"url = [%@]", url);

    BOOL ret =[UIApplication.sharedApplication canOpenURL:url];

    XCTAssertNotNil(url);
    XCTAssertTrue(ret);
}

- (void)testCyrillicWithPath {
    NSString* unc = @"http://api.com/алматы/events";
    NSURL* url = unc.mmcgUrl;
    
    NSLog(@"url = [%@]", url);
    
    BOOL ret =[UIApplication.sharedApplication canOpenURL:url];

    XCTAssertNotNil(url);
    XCTAssertTrue(ret);
}

- (void)testCyrillic2WithPath {
    NSString* unc = @"http://example.com/мама";
    NSURL* url = unc.mmcgUrl;
    
    NSLog(@"url = [%@]", url);
    
    BOOL ret =[UIApplication.sharedApplication canOpenURL:url];

    XCTAssertNotNil(url);
    XCTAssertTrue(ret);
}

- (void)testCyrillic3WithPath {
    NSString* unc = @"https://ru.wikipedia.org/wiki/Swift_(язык_программирования)";
    NSURL* url = unc.mmcgUrl;
    
    NSLog(@"url = [%@]", url);
    
    BOOL ret =[UIApplication.sharedApplication canOpenURL:url];

    XCTAssertNotNil(url);
    XCTAssertTrue(ret);
}

- (void)testCyrilli4WithOtherComponents {
    NSString* unc = @"https://ru.wikipedia.org/wiki/Swift_(язык_программирования)?foo=bar&dog=cat#fragment";
    NSURL* url = unc.mmcgUrl;
    
    NSLog(@"url = [%@]", url);
    
    BOOL ret =[UIApplication.sharedApplication canOpenURL:url];

    XCTAssertNotNil(url);
    XCTAssertTrue(ret);
}

@end
