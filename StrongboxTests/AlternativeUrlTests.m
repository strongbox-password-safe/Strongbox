//
//  AlternativeUrlTests.m
//  StrongboxTests
//
//  Created by Mark on 09/01/2020.
//  Copyright © 2020 Mark McGuill. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "Node.h"

@interface AlternativeUrlTests : XCTestCase

@end

@implementation AlternativeUrlTests

- (void)testNoCustomFields {
    NodeFields* fields = [[NodeFields alloc] initWithUsername:@"username" url:@"https://example.com" password:@"1234" notes:@"Random notes" email:@"mark@mark.com"];
    
    XCTAssertTrue(fields.alternativeUrls.count == 0);
}

- (void)testUnrelatedCustomField {
    NodeFields* fields = [[NodeFields alloc] initWithUsername:@"username" url:@"https://example.com" password:@"1234" notes:@"Random notes" email:@"mark@mark.com"];
    
    [fields setCustomField:@"Foo" value:[StringValue valueWithString:@"Bar"]];
    
    XCTAssertTrue(fields.alternativeUrls.count == 0);
}

- (void)testPoorlyInitialized {
    NodeFields* fields = [[NodeFields alloc] init];
    
    XCTAssertTrue(fields.alternativeUrls.count == 0);
}

- (void)testSingleNoSuffixAlternativeUrl {
    NodeFields* fields = [[NodeFields alloc] initWithUsername:@"username" url:@"https://example.com" password:@"1234" notes:@"Random notes" email:@"mark@mark.com"];
    
    [fields setCustomField:@"KP2A_URL" value:[StringValue valueWithString:@"https://example1.com/"]];
    
    NSArray<NSString*> *alts = fields.alternativeUrls;
    
    XCTAssertTrue(alts.count == 1);
}

- (void)testSingleWithSuffixAlternativeUrl {
    NodeFields* fields = [[NodeFields alloc] initWithUsername:@"username" url:@"https://example.com" password:@"1234" notes:@"Random notes" email:@"mark@mark.com"];
    
    [fields setCustomField:@"KP2A_URL_1" value:[StringValue valueWithString:@"https://example1.com/"]];
    
    NSArray<NSString*> *alts = fields.alternativeUrls;
    
    XCTAssertTrue(alts.count == 1);
}

- (void)testMultipleAlternativeUrls {
    NodeFields* fields = [[NodeFields alloc] initWithUsername:@"username" url:@"https://example.com" password:@"1234" notes:@"Random notes" email:@"mark@mark.com"];

    [fields setCustomField:@"KP2A_URL" value:[StringValue valueWithString:@"https://example1.com/"]];
    [fields setCustomField:@"KP2A_URL_1" value:[StringValue valueWithString:@"https://example2.com/"]];
    [fields setCustomField:@"KP2A_URL_12" value:[StringValue valueWithString:@"https://example3.com/"]];

    NSArray<NSString*> *alts = fields.alternativeUrls;
    
    XCTAssertTrue(alts.count == 3);
}

@end
