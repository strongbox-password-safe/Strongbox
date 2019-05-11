//
//  KeePassKeyFileTests.m
//  StrongboxTests
//
//  Created by Mark on 24/11/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "KeePassDatabase.h"
#import "CommonTesting.h"
#import "Kdb1Database.h"
#import "Utils.h"

@interface KeePassKeyFileTests : XCTestCase

@end

@implementation KeePassKeyFileTests

- (void)testKeePass2 {
    NSData *data = [CommonTesting getDataFromBundleFile:@"kp2-keyfile" ofType:@"kdbx"];
    NSData *keyFileDigest = sha256([CommonTesting getDataFromBundleFile:@"ferrari" ofType:@"jpg"]);
    
    XCTAssert(data);
    XCTAssert(keyFileDigest);
    
    NSError *error;
    KeePassDatabase* adaptor = [[KeePassDatabase alloc] init];
    StrongboxDatabase *db = [adaptor open:data password:@"a" keyFileDigest:keyFileDigest error:&error];
    
    XCTAssert(db);
    
    NSLog(@"%@", db);
}

- (void)testKeePass1 {
    NSData *data = [CommonTesting getDataFromBundleFile:@"kp1-keyfile" ofType:@"kdb"];
    NSData *keyFileDigest = sha256([CommonTesting getDataFromBundleFile:@"ferrari" ofType:@"jpg"]);

    XCTAssert(data);
    XCTAssert(keyFileDigest);
    
    NSError *error;
    Kdb1Database* adaptor = [[Kdb1Database alloc] init];
    StrongboxDatabase *db = [adaptor open:data password:@"a" keyFileDigest:keyFileDigest error:&error];
    
    XCTAssert(db);

    NSLog(@"%@", db);
}

- (void)testKeePass2KeyFileOnly {
    NSData *data = [CommonTesting getDataFromBundleFile:@"kp2-keyfile-only" ofType:@"kdbx"];
    NSData *keyFileDigest = sha256([CommonTesting getDataFromBundleFile:@"ferrari" ofType:@"jpg"]);
    
    XCTAssert(data);
    XCTAssert(keyFileDigest);
    
    NSError *error;
    KeePassDatabase* adaptor = [[KeePassDatabase alloc] init];
    StrongboxDatabase *db = [adaptor open:data password:nil keyFileDigest:keyFileDigest error:&error];
    
    XCTAssert(db);
    
    NSLog(@"%@", db);
}

- (void)testKeePass2KeyFileOnlyEmptyNotNil {
    NSData *data = [CommonTesting getDataFromBundleFile:@"kp2-keyfile-only" ofType:@"kdbx"];
    NSData *keyFileDigest = sha256([CommonTesting getDataFromBundleFile:@"ferrari" ofType:@"jpg"]);
    
    XCTAssert(data);
    XCTAssert(keyFileDigest);
    
    NSError *error;
    KeePassDatabase* adaptor = [[KeePassDatabase alloc] init];
    StrongboxDatabase *db = [adaptor open:data password:nil keyFileDigest:keyFileDigest error:&error];
    
    XCTAssert(db);
    
    NSLog(@"%@", db);
}

- (void)testKeePass1KeyFileOnly {
    NSData *data = [CommonTesting getDataFromBundleFile:@"kp1-keyfile-only" ofType:@"kdb"];
    NSData *keyFileDigest = sha256([CommonTesting getDataFromBundleFile:@"ferrari" ofType:@"jpg"]);
    
    XCTAssert(data);
    XCTAssert(keyFileDigest);
    
    NSError *error;
    Kdb1Database* adaptor = [[Kdb1Database alloc] init];
    StrongboxDatabase *db = [adaptor open:data password:nil keyFileDigest:keyFileDigest error:&error];
    
    XCTAssert(db);
    NSLog(@"%@", db);
}

- (void)testKeePass1KeyFileOnlyEmptyNotNil {
    NSData *data = [CommonTesting getDataFromBundleFile:@"kp1-keyfile-only" ofType:@"kdb"];
    NSData *keyFileDigest = sha256([CommonTesting getDataFromBundleFile:@"ferrari" ofType:@"jpg"]);
    
    XCTAssert(data);
    XCTAssert(keyFileDigest);
    
    NSError *error;
    Kdb1Database* adaptor = [[Kdb1Database alloc] init];
    StrongboxDatabase *db = [adaptor open:data password:@"" keyFileDigest:keyFileDigest error:&error];
    
    XCTAssert(db);
    NSLog(@"%@", db);
}

- (void)testKeePass1OpenSaveOpen {
    NSData *data = [CommonTesting getDataFromBundleFile:@"kp1-keyfile-only" ofType:@"kdb"];
    NSData *keyFileDigest = sha256([CommonTesting getDataFromBundleFile:@"ferrari" ofType:@"jpg"]);
    
    XCTAssert(data);
    XCTAssert(keyFileDigest);
    
    NSError *error;
    Kdb1Database* adaptor = [[Kdb1Database alloc] init];
    StrongboxDatabase *db = [adaptor open:data password:nil keyFileDigest:keyFileDigest error:&error];
    
    XCTAssert(db);
    NSData* saved = [adaptor save:db error:&error];
    XCTAssert(saved);
    StrongboxDatabase *reopened = [adaptor open:saved password:nil keyFileDigest:keyFileDigest error:&error];
    
    XCTAssert(reopened);
    NSLog(@"%@", reopened);
}

- (void)testKeePass2OpenSaveOpen {
    NSData *data = [CommonTesting getDataFromBundleFile:@"kp2-keyfile-only" ofType:@"kdbx"];
    NSData *keyFileDigest = sha256([CommonTesting getDataFromBundleFile:@"ferrari" ofType:@"jpg"]);
    
    XCTAssert(data);
    XCTAssert(keyFileDigest);
    
    NSError *error;
    KeePassDatabase* adaptor = [[KeePassDatabase alloc] init];
    StrongboxDatabase *db = [adaptor open:data password:nil keyFileDigest:keyFileDigest error:&error];
    
    XCTAssert(db);
    NSData* saved = [adaptor save:db error:&error];
    XCTAssert(saved);
    StrongboxDatabase *reopened = [adaptor open:saved password:nil keyFileDigest:keyFileDigest error:&error];
    
    XCTAssert(reopened);
    NSLog(@"%@", reopened);
}

@end

