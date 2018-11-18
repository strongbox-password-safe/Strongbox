//
//  KdbDatabaseTests.m
//  StrongboxTests
//
//  Created by Mark on 08/11/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "CommonTesting.h"
#import "Kdb1Database.h"

@interface KdbDatabaseTests : XCTestCase

@end

@implementation KdbDatabaseTests

- (void)testInitExistingWithAllKdbTestFiles {
    for (NSString* file in CommonTesting.testKdbFilesAndPasswords) {
        NSLog(@"=============================================================================================================");
        NSLog(@"===================================== %@ ===============================================", file);
        
        NSData *blob = [CommonTesting getDataFromBundleFile:file ofType:@"kdb"];
        XCTAssert(blob);
        
        NSError* error;
        NSString* password = [CommonTesting.testKdbFilesAndPasswords objectForKey:file];
        
        if(![Kdb1Database isAValidSafe:blob]) {
            XCTAssert(NO);
            continue;
        }
        
        id<AbstractDatabaseFormatAdaptor> adaptor = [[Kdb1Database alloc] init];
        StrongboxDatabase *db = [adaptor open:blob password:password error:&error];
        
        XCTAssertNotNil(db);
        
        NSLog(@"%@", db);
        NSLog(@"=============================================================================================================");
    }
}

- (void)testAesReadOnly {
    NSData *blob = [CommonTesting getDataFromBundleFile:@"Database-1" ofType:@"kdb"];
    XCTAssert(blob);
    
    NSError* error;
    NSString* password = [CommonTesting.testKdbFilesAndPasswords objectForKey:@"Database-1"];
    
    id<AbstractDatabaseFormatAdaptor> adaptor = [[Kdb1Database alloc] init];
    StrongboxDatabase *db = [adaptor open:blob password:password error:&error];
    
    XCTAssertNotNil(db);
    
    NSLog(@"%@", db);
}

- (void)testTwoFish {
    NSData *blob = [CommonTesting getDataFromBundleFile:@"Database-twofish" ofType:@"kdb"];
    XCTAssert(blob);
    
    NSError* error;
    NSString* password = [CommonTesting.testKdbFilesAndPasswords objectForKey:@"Database-twofish"];
    
    id<AbstractDatabaseFormatAdaptor> adaptor = [[Kdb1Database alloc] init];
    StrongboxDatabase *db = [adaptor open:blob password:password error:&error];
    
    XCTAssertNotNil(db);
    
    NSLog(@"%@", db);
}

- (void)testAesRw {
    NSData *blob = [CommonTesting getDataFromBundleFile:@"Database-1" ofType:@"kdb"];
    XCTAssert(blob);
    
    NSError* error;
    NSString* password = [CommonTesting.testKdbFilesAndPasswords objectForKey:@"Database-1"];
    
    id<AbstractDatabaseFormatAdaptor> adaptor = [[Kdb1Database alloc] init];
    StrongboxDatabase *db = [adaptor open:blob password:password error:&error];
    
    XCTAssertNotNil(db);
    
    NSLog(@"BEFORE: %@", db);
    
    //db.masterPassword = @"ladder";
    NSData* rec = [adaptor save:db error:&error];

    StrongboxDatabase *b = [adaptor open:rec password:db.masterPassword error:&error];
    NSLog(@"AFTER: %@", b);
    
    XCTAssertNotNil(b);
}

@end
