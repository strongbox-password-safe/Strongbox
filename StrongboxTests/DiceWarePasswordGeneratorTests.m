//
//  DiceWarePasswordGeneratorTests.m
//  StrongboxTests
//
//  Created by Mark on 28/01/2019.
//  Copyright © 2019 Mark McGuill. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "PasswordGenerator.h"

@interface DiceWarePasswordGeneratorTests : XCTestCase

@end

@implementation DiceWarePasswordGeneratorTests

- (void)testEffLargeWith4 {
    NSString* pw = [PasswordGenerator generateDicewareStylePassword:@"-" wordList:kEffLarge wordCount:4];

    NSLog(@"%@", pw);

    XCTAssertNotNil(pw);
}



@end
