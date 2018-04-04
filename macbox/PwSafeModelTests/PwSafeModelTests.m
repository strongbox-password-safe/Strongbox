//
//  PwSafeModelTests.m
//  PwSafeModelTests
//
//  Created by Mark on 20/08/2017.
//  Copyright © 2017 Mark McGuill. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "Group.h"

@interface PwSafeModelTests : XCTestCase

@end

@implementation PwSafeModelTests

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testEmptyStringIsRoot {
    Group* group = [[Group alloc] initWithEscapedPathString:@""];
    
    XCTAssert(group.isRootGroup);
}

- (void)testNilStringIsRoot {
    Group* group = [[Group alloc] initWithEscapedPathString:nil];
    
    XCTAssert(group.isRootGroup);
}

- (void)testDotStringIsRoot {
    Group* group = [[Group alloc] initWithEscapedPathString:@"."];
    
    XCTAssert(group.isRootGroup);
}

- (void)testMultipleDotStringIsRoot {
    Group* group = [[Group alloc] initWithEscapedPathString:@"......"];
    
    XCTAssert(group.isRootGroup);
}

- (void)testMultipleDotStringHasZeroComponents {
    Group* group = [[Group alloc] initWithEscapedPathString:@"......"];
    
    XCTAssert(group.pathComponents.count == 0);
}

- (void)testGroupCreationWithNilPathComponents {
    Group* group = [[Group alloc] initWithPathComponents:nil];
   
    XCTAssert(group.isRootGroup);
    
    NSLog(@"%@ -> %@", group.escapedPathString, group.title);
}

- (void)testGroupCreateWithDotAsTitleGetsRecreatedCorrectly {
    Group* group = [[Group alloc] initAsRootGroup];
    
    Group *child = [group createChildGroupWithTitle:@"."];
    
    NSLog(@"%@ -> %@", child.escapedPathString, child.title);
    
    Group *recreatedChild = [[Group alloc] initWithEscapedPathString:child.escapedPathString];
    
    XCTAssert([child isEqual:recreatedChild]);
}

- (void)testGetDirectAncestorUsingNilForRoot {
    Group* group = [[Group alloc] initAsRootGroup];
    Group *child = [group createChildGroupWithTitle:@"foo"];
    Group *grandchild = [child createChildGroupWithTitle:@"bar"];
    
    NSLog(@"%@ -> %@", grandchild.escapedPathString, grandchild.title);
    
    Group *shouldbeChild = [grandchild getDirectAncestorOfParent:nil];

    NSLog(@"%@ -> %@", shouldbeChild.escapedPathString, shouldbeChild.title);
    
    XCTAssert([child isEqual:shouldbeChild]);
}

- (void)testGetDirectAncestor {
    Group* group = [[Group alloc] initAsRootGroup];
    Group *child = [group createChildGroupWithTitle:@"foo"];
    Group *grandchild = [child createChildGroupWithTitle:@"bar"];
    
    NSLog(@"%@ -> %@", grandchild.escapedPathString, grandchild.title);
    
    Group *shouldbeChild = [grandchild getDirectAncestorOfParent:group];
    
    NSLog(@"%@ -> %@", shouldbeChild.escapedPathString, shouldbeChild.title);
    
    XCTAssert([child isEqual:shouldbeChild]);
}

@end
