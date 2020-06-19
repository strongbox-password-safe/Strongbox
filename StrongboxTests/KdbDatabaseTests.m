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
        
        if(![Kdb1Database isAValidSafe:blob error:&error]) {
            XCTAssert(NO);
            continue;
        }
        
        id<AbstractDatabaseFormatAdaptor> adaptor = [[Kdb1Database alloc] init];
        [adaptor open:blob ckf:[CompositeKeyFactors password:password] useLegacyDeserialization:NO completion:^(BOOL userCancelled, StrongboxDatabase * _Nullable db, NSError * _Nullable error) {
            XCTAssertNotNil(db);
            
            NSLog(@"%@", db);
            NSLog(@"=============================================================================================================");
        }];
    }
}

- (void)testAesReadOnly {
    NSData *blob = [CommonTesting getDataFromBundleFile:@"Database-1" ofType:@"kdb"];
    XCTAssert(blob);
    
    NSString* password = [CommonTesting.testKdbFilesAndPasswords objectForKey:@"Database-1"];
    
    id<AbstractDatabaseFormatAdaptor> adaptor = [[Kdb1Database alloc] init];
    [adaptor open:blob
              ckf:[CompositeKeyFactors password:password] useLegacyDeserialization:NO
       completion:^(BOOL userCancelled, StrongboxDatabase * _Nullable db, NSError * _Nullable error) {
        XCTAssertNotNil(db);
        NSLog(@"%@", db);
    }];
}

- (void)testTwoFish {
    NSData *blob = [CommonTesting getDataFromBundleFile:@"Database-twofish" ofType:@"kdb"];
    XCTAssert(blob);
    
    NSString* password = [CommonTesting.testKdbFilesAndPasswords objectForKey:@"Database-twofish"];
    
    id<AbstractDatabaseFormatAdaptor> adaptor = [[Kdb1Database alloc] init];
    
    [adaptor open:blob ckf:[CompositeKeyFactors password:password] useLegacyDeserialization:NO completion:^(BOOL userCancelled, StrongboxDatabase * _Nullable db, NSError * _Nullable error) {
        XCTAssertNotNil(db);
        NSLog(@"%@", db);
    }];
}

- (void)testAesRw {
    NSData *blob = [CommonTesting getDataFromBundleFile:@"Database-1" ofType:@"kdb"];
    XCTAssert(blob);
    
    NSString* password = [CommonTesting.testKdbFilesAndPasswords objectForKey:@"Database-1"];
    
    id<AbstractDatabaseFormatAdaptor> adaptor = [[Kdb1Database alloc] init];
    
    [adaptor open:blob ckf:[CompositeKeyFactors password:password] useLegacyDeserialization:NO completion:^(BOOL userCancelled, StrongboxDatabase * _Nullable db, NSError * _Nullable error) {
        XCTAssertNotNil(db);
        
        NSLog(@"BEFORE: %@", db);
        
        //db.masterPassword = @"ladder";
        
        [adaptor save:db completion:^(BOOL userCancelled, NSData * _Nullable rec, NSError * _Nullable error) {
            [adaptor open:rec ckf:[CompositeKeyFactors password:db.compositeKeyFactors.password] useLegacyDeserialization:NO completion:^(BOOL userCancelled, StrongboxDatabase * _Nullable b, NSError * _Nullable error) {
                NSLog(@"AFTER: %@", b);
                XCTAssertNotNil(b);
            }];
        }];
    }];
}

@end
