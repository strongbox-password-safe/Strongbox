//
//  YubiKeyTests.m
//  StrongboxTests
//
//  Created by Mark on 28/09/2019.
//  Copyright © 2019 Mark McGuill. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "YubiManager.h"

@interface YubiKeyTests : XCTestCase

@end

@implementation YubiKeyTests

- (void)testExample {
    [YubiManager.sharedInstance doIt];
}

@end
