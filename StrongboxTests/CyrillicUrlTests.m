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
    NSURL* url = unc.urlExtendedParse;
    NSLog(@"url = [%@]", url);

    XCTAssertNotNil(url);
}

- (void)testInvalidScheme {
    NSString* unc = @"чa://честныйзнак.рф";
    NSURL* url = unc.urlExtendedParse;
    NSLog(@"url = [%@]", url);

    XCTAssertNotNil(url);
}

- (void)testCyrillicNoPath {
    NSString* unc = @"https://честныйзнак.рф";
    NSURL* url = unc.urlExtendedParse;
    NSLog(@"url = [%@]", url);

    BOOL ret =[UIApplication.sharedApplication canOpenURL:url];

    XCTAssertNotNil(url);
    XCTAssertTrue(ret);
}

- (void)testCyrillic {
    NSString* unc = @"https://честныйзнак.рф/";
    NSURL* url = unc.urlExtendedParse;
    NSLog(@"url = [%@]", url);

    BOOL ret =[UIApplication.sharedApplication canOpenURL:url];

    XCTAssertNotNil(url);
    XCTAssertTrue(ret);
}

- (void)testCyrillic2 {
    NSString* unc = @"http://мфц-омск.рф/";
    NSURL* url = unc.urlExtendedParse;
    NSLog(@"url = [%@]", url);

    BOOL ret =[UIApplication.sharedApplication canOpenURL:url];

    XCTAssertNotNil(url);
    XCTAssertTrue(ret);
}

- (void)testCyrillicWithPath {
    NSString* unc = @"http://api.com/алматы/events";
    NSURL* url = unc.urlExtendedParse;
    
    NSLog(@"url = [%@]", url);
    
    BOOL ret =[UIApplication.sharedApplication canOpenURL:url];

    XCTAssertNotNil(url);
    XCTAssertTrue(ret);
}

- (void)testCyrillic2WithPath {
    NSString* unc = @"http://example.com/мама";
    NSURL* url = unc.urlExtendedParse;
    
    NSLog(@"url = [%@]", url);
    
    BOOL ret =[UIApplication.sharedApplication canOpenURL:url];

    XCTAssertNotNil(url);
    XCTAssertTrue(ret);
}

- (void)testCyrillic3WithPath {
    NSString* unc = @"https://ru.wikipedia.org/wiki/Swift_(язык_программирования)";
    NSURL* url = unc.urlExtendedParse;
    
    NSLog(@"url = [%@]", url);
    
    BOOL ret =[UIApplication.sharedApplication canOpenURL:url];

    XCTAssertNotNil(url);
    XCTAssertTrue(ret);
}

- (void)testCyrilli4WithOtherComponents {
    NSString* unc = @"https://ru.wikipedia.org/wiki/Swift_(язык_программирования)?foo=bar&dog=cat#fragment";
    NSURL* url = unc.urlExtendedParse;
    
    NSLog(@"url = [%@]", url);
    
    BOOL ret =[UIApplication.sharedApplication canOpenURL:url];

    XCTAssertNotNil(url);
    XCTAssertTrue(ret);
}

- (void)testCyrillicWithUser {
    NSString* unc = @"https://user@ru.wikipedia.org/wiki/Swift_(язык_программирования)?foo=bar&dog=cat#fragment";

    NSURL* url = unc.urlExtendedParse;
    NSLog(@"url = [%@] - user: [%@], password: [%@]", url, url.user, url.password);
    
    BOOL ret = [UIApplication.sharedApplication canOpenURL:url];

    XCTAssertNotNil(url);
    XCTAssertTrue([url.user isEqualToString:@"user"]);
    XCTAssertNil(url.password);
    XCTAssertTrue(ret);
}

- (void)testCyrillicWithPassword {
    NSString* unc = @"https://user:pw@ru.wikipedia.org/wiki/Swift_(язык_программирования)?foo=bar&dog=cat#fragment";
    NSURL* url = unc.urlExtendedParse;
    
    NSLog(@"url = [%@] - user: [%@], password: [%@]", url, url.user, url.password);
    
    BOOL ret =[UIApplication.sharedApplication canOpenURL:url];

    XCTAssertNotNil(url);
    
    XCTAssertTrue([url.user isEqualToString:@"user"]);
    XCTAssertTrue([url.password isEqualToString:@"pw"]);

    XCTAssertTrue(ret);
}

- (void)testCyrillicWithPort {
    NSString* unc = @"https://ru.wikipedia.org:1234/wiki/Swift_(язык_программирования)?foo=bar&dog=cat#fragment";
    NSURL* url = unc.urlExtendedParse;
    
    NSLog(@"url = [%@] - user: [%@], password: [%@], port : [%@]", url, url.user, url.password, url.port);
    
    BOOL ret =[UIApplication.sharedApplication canOpenURL:url];

    XCTAssertNotNil(url.port);
    XCTAssertTrue(url.port.integerValue == 1234);
    XCTAssertNotNil(url);
    XCTAssertTrue(ret);
}

- (void)testCyrillicWithUserAndPort {
    NSString* unc = @"https://user@ru.wikipedia.org:1234/wiki/Swift_(язык_программирования)?foo=bar&dog=cat#fragment";
    NSURL* url = unc.urlExtendedParse;
    
    NSLog(@"url = [%@] - user: [%@], password: [%@], port : [%@]", url, url.user, url.password, url.port);
    
    BOOL ret =[UIApplication.sharedApplication canOpenURL:url];

    XCTAssertNotNil(url.port);
    XCTAssertTrue(url.port.integerValue == 1234);
    XCTAssertTrue([url.user isEqualToString:@"user"]);
    XCTAssertNil(url.password);
    XCTAssertNotNil(url);
    XCTAssertTrue(ret);
}

- (void)testCyrillicWithUserAndPasswordAndPort {
    NSString* unc = @"https://user:pw@ru.wikipedia.org:1234/wiki/Swift_(язык_программирования)?foo=bar&dog=cat#fragment";
    NSURL* url = unc.urlExtendedParse;
    
    NSLog(@"url = [%@] - user: [%@], password: [%@], port : [%@]", url, url.user, url.password, url.port);
    
    BOOL ret =[UIApplication.sharedApplication canOpenURL:url];

    XCTAssertNotNil(url.port);
    XCTAssertTrue(url.port.integerValue == 1234);
    XCTAssertTrue([url.user isEqualToString:@"user"]);
    XCTAssertTrue([url.password isEqualToString:@"pw"]);
    XCTAssertNotNil(url);
    XCTAssertTrue(ret);
}


- (void)testCyrillicWithUserAndPasswordAndCrapPort {
    NSString* unc = @"https://user:pw@ru.wikipedia.org:nonsense/wiki/Swift_(язык_программирования)?foo=bar&dog=cat#fragment";
    NSURL* url = unc.urlExtendedParse;
    
    NSLog(@"url = [%@] - user: [%@], password: [%@], port : [%@]", url, url.user, url.password, url.port);
    
    BOOL ret =[UIApplication.sharedApplication canOpenURL:url];

    XCTAssertNil(url.port);
    XCTAssertTrue([url.user isEqualToString:@"user"]);
    XCTAssertTrue([url.password isEqualToString:@"pw"]);
    XCTAssertNotNil(url);
    XCTAssertTrue(ret);
}
@end
