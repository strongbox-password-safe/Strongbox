//
//  PasswordMakerTests.m
//  StrongboxTests
//
//  Created by Mark on 29/06/2019.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "PasswordMaker.h"
#import "SBLog.h"
@interface PasswordMakerTests : XCTestCase

@end

@implementation PasswordMakerTests

- (void)testDefaults {
    NSString* password = [PasswordMaker.sharedInstance generateForConfig:[PasswordGenerationConfig defaults]];
    
    slog(@"Generated: [%@]", password);
    
    XCTAssertNotNil(password);
}

- (void)testAllPoolsWithVeryShortLength {
    PasswordGenerationConfig* config = [PasswordGenerationConfig defaults];
    config.basicLength = 4;
    config.useCharacterGroups = @[@(kPasswordGenerationCharacterPoolUpper),
                                @(kPasswordGenerationCharacterPoolLower),
                                @(kPasswordGenerationCharacterPoolNumeric),
                                @(kPasswordGenerationCharacterPoolSymbols)];

    NSString* password = [PasswordMaker.sharedInstance generateForConfig:config];
    
    slog(@"Generated: [%@]", password);
    
    XCTAssertNotNil(password);
}

- (void)testDiceware {
    PasswordGenerationConfig* config = [PasswordGenerationConfig defaults];
    config.wordCount = 4;
    config.algorithm = kPasswordGenerationAlgorithmDiceware;
    
    NSString* password = [PasswordMaker.sharedInstance generateForConfig:config];
    
    slog(@"Generated: [%@]", password);
    
    XCTAssertNotNil(password);
}












@end
