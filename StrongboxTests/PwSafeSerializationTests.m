//
//  PwSafeSerializationTests.m
//  StrongboxTests
//
//  Created by Mark on 23/10/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "PwSafeDatabase.h"

@interface PwSafeSerializationTests : XCTestCase

@end

@implementation PwSafeSerializationTests

- (void)testOpenSimple {
    NSBundle *bundle = [NSBundle bundleForClass:[self class]];
    NSString *path = [bundle pathForResource:@"simple-unit-test-strongbox" ofType:@"dat"];
    NSData* safeData = [NSData dataWithContentsOfFile:path];
    
    NSError *error;
    PwSafeDatabase *db = [[PwSafeDatabase alloc] initExistingWithDataAndPassword:safeData password:@"a" error:&error];

    if(!db) {
        NSLog(@"ERROR: %@", error);
        return;
    }
    
    XCTAssertNotNil(db);
    
    NSLog(@"%@", [db getDiagnosticDumpString:YES]);
}

- (void)testLargeMemoryConsumption {
    NSBundle *bundle = [NSBundle bundleForClass:[self class]];
    NSString *path = [bundle pathForResource:@"pwsafe-mem-consumption" ofType:@"psafe3"];
    NSData* safeData = [NSData dataWithContentsOfFile:path];
    
    NSError *error;
    PwSafeDatabase *db = [[PwSafeDatabase alloc] initExistingWithDataAndPassword:safeData password:@"M1cr0s0ft" error:&error];
    
    if(!db) {
        NSLog(@"ERROR: %@", error);
        return;
    }
    
    XCTAssertNotNil(db);
    
    NSLog(@"%@", db); // [db getDiagnosticDumpString:YES]);
}

@end
