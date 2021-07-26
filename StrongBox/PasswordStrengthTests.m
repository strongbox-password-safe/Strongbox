//
//  PasswordStrengthTests.m
//  StrongboxTests
//
//  Created by Strongbox on 12/04/2021.
//  Copyright © 2021 Mark McGuill. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "PasswordStrengthTester.h"

@interface PasswordStrengthTests : XCTestCase

@end

@implementation PasswordStrengthTests

- (void)testWithConfig {
    PasswordStrength *strength = [PasswordStrengthTester getStrength:@"correcthorsebatterystaple" config:PasswordStrengthConfig.defaults];
    NSLog(@"Entropy: %f", strength.entropy);
}

- (void)testXkcd {
    double strength = [PasswordStrengthTester getSimpleStrength:@"correcthorsebatterystaple"];
    NSLog(@"Entropy: %f", strength);
}

- (void)testLowerOnly {
    double strength = [PasswordStrengthTester getSimpleStrength:@"princess"];
    NSLog(@"Entropy: %f", strength);
}

- (void)testUpperOnly {
    double strength = [PasswordStrengthTester getSimpleStrength:@"PRINCESS"];
    NSLog(@"Entropy: %f", strength);
}

- (void)testUpperAndLower {
    double strength = [PasswordStrengthTester getSimpleStrength:@"PRINCESs"];
    NSLog(@"Entropy: %f", strength);
}

- (void)testUpperAndLowerAndNumeric {
    double strength = [PasswordStrengthTester getSimpleStrength:@"PRINC3Ss"];
    NSLog(@"Entropy: %f", strength);
}

- (void)testUpperAndLowerAndNumericAndSymbolic {
    double strength = [PasswordStrengthTester getSimpleStrength:@"PR!NC3Ss"];
    NSLog(@"Entropy: %f", strength);
}

- (void)testUpperAndLowerAndNumericAndSymbolicAndSpace {
    double strength = [PasswordStrengthTester getSimpleStrength:@"PR!N c3S"];
    NSLog(@"Entropy: %f", strength);
}

- (void)testUpperAndLowerAndNumericAndSymbolicAndSpaceAndExtendedAscii {
    double strength = [PasswordStrengthTester getSimpleStrength:@"P!N c3S\u00A1"];
    NSLog(@"Entropy: %f", strength);
}

- (void)testWeirdUnicode {
    double strength = [PasswordStrengthTester getSimpleStrength:@"mañana"];
    NSLog(@"Entropy: %f", strength);
}

- (void)testWeirdUnicode2 { 
    double strength = [PasswordStrengthTester getSimpleStrength:@"e̊gâds"];
    NSLog(@"Entropy: %f", strength);
}

- (void)testZxcvbn {
    double strength = [PasswordStrengthTester getZxcvbnStrength:@"princess"];
    NSLog(@"Entropy: %f", strength);
}

@end
