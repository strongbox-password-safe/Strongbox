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
#import "NSData+Extensions.h"

@interface KeePassKeyFileTests : XCTestCase

@end

@implementation KeePassKeyFileTests

- (void)testKeePass2 {
    NSData *data = [CommonTesting getDataFromBundleFile:@"kp2-keyfile" ofType:@"kdbx"];
    NSData *keyFileDigest = [CommonTesting getDataFromBundleFile:@"ferrari" ofType:@"jpg"].sha256;
    
    XCTAssert(data);
    XCTAssert(keyFileDigest);
    
    KeePassDatabase* adaptor = [[KeePassDatabase alloc] init];
    NSInputStream* stream = [NSInputStream inputStreamWithData:data];
    [stream open];
     [adaptor read:stream ckf:[CompositeKeyFactors password:@"a" keyFileDigest:keyFileDigest] completion:^(BOOL userCancelled, StrongboxDatabase * _Nullable db, NSError * _Nullable error) {
        XCTAssert(db);
        NSLog(@"%@", db);
    }];
}

- (void)testKeePass1 {
    NSData *data = [CommonTesting getDataFromBundleFile:@"kp1-keyfile" ofType:@"kdb"];
    NSData *keyFileDigest = [CommonTesting getDataFromBundleFile:@"ferrari" ofType:@"jpg"].sha256;

    XCTAssert(data);
    XCTAssert(keyFileDigest);
    
    Kdb1Database* adaptor = [[Kdb1Database alloc] init];

    NSInputStream* stream = [NSInputStream inputStreamWithData:data];
    [stream open];
     [adaptor read:stream ckf:[CompositeKeyFactors password:@"a" keyFileDigest:keyFileDigest] completion:^(BOOL userCancelled, StrongboxDatabase * _Nullable db, NSError * _Nullable error) {
        XCTAssert(db);
        NSLog(@"%@", db);
    }];
}

- (void)testKeePass2KeyFileOnly {
    NSData *data = [CommonTesting getDataFromBundleFile:@"kp2-keyfile-only" ofType:@"kdbx"];
    NSData *keyFileDigest = [CommonTesting getDataFromBundleFile:@"ferrari" ofType:@"jpg"].sha256;
    
    XCTAssert(data);
    XCTAssert(keyFileDigest);
    
    KeePassDatabase* adaptor = [[KeePassDatabase alloc] init];
    
    NSInputStream* stream = [NSInputStream inputStreamWithData:data];
    [stream open];
    
     [adaptor read:stream ckf:[CompositeKeyFactors password:nil keyFileDigest:keyFileDigest] completion:^(BOOL userCancelled, StrongboxDatabase * _Nullable db, NSError * _Nullable error) {
        XCTAssert(db);
        NSLog(@"%@", db);
    }];
}

- (void)testKeePass2KeyFileOnlyEmptyNotNil {
    NSData *data = [CommonTesting getDataFromBundleFile:@"kp2-keyfile-only" ofType:@"kdbx"];
    NSData *keyFileDigest = [CommonTesting getDataFromBundleFile:@"ferrari" ofType:@"jpg"].sha256;
    
    XCTAssert(data);
    XCTAssert(keyFileDigest);
    
    KeePassDatabase* adaptor = [[KeePassDatabase alloc] init];

    NSInputStream* stream = [NSInputStream inputStreamWithData:data];
    [stream open];
    
     [adaptor read:stream ckf:[CompositeKeyFactors password:nil keyFileDigest:keyFileDigest] completion:^(BOOL userCancelled, StrongboxDatabase * _Nullable db, NSError * _Nullable error) {
        XCTAssert(db);
        NSLog(@"%@", db);
    }];
}

- (void)testKeePass1KeyFileOnly {
    NSData *data = [CommonTesting getDataFromBundleFile:@"kp1-keyfile-only" ofType:@"kdb"];
    NSData *keyFileDigest = [CommonTesting getDataFromBundleFile:@"ferrari" ofType:@"jpg"].sha256;
    
    XCTAssert(data);
    XCTAssert(keyFileDigest);
    
    Kdb1Database* adaptor = [[Kdb1Database alloc] init];
    
    NSInputStream* stream = [NSInputStream inputStreamWithData:data];
    [stream open];
     [adaptor read:stream ckf:[CompositeKeyFactors password:nil keyFileDigest:keyFileDigest] completion:^(BOOL userCancelled, StrongboxDatabase * _Nullable db, NSError * _Nullable error) {
        XCTAssert(db);
        NSLog(@"%@", db);
    }];
}

- (void)testKeePass1KeyFileOnlyEmptyNotNil {
    NSData *data = [CommonTesting getDataFromBundleFile:@"kp1-keyfile-only" ofType:@"kdb"];
    NSData *keyFileDigest = [CommonTesting getDataFromBundleFile:@"ferrari" ofType:@"jpg"].sha256;
    
    XCTAssert(data);
    XCTAssert(keyFileDigest);
    
    Kdb1Database* adaptor = [[Kdb1Database alloc] init];
    
    NSInputStream* stream = [NSInputStream inputStreamWithData:data];
    [stream open];
    
     [adaptor read:stream ckf:[CompositeKeyFactors password:@"" keyFileDigest:keyFileDigest] completion:^(BOOL userCancelled, StrongboxDatabase * _Nullable db, NSError * _Nullable error) {
        XCTAssert(db);
        NSLog(@"%@", db);
    }];
}

- (void)testKeePass1OpenSaveOpen {
    NSData *data = [CommonTesting getDataFromBundleFile:@"kp1-keyfile-only" ofType:@"kdb"];
    NSData *keyFileDigest = [CommonTesting getDataFromBundleFile:@"ferrari" ofType:@"jpg"].sha256;
    
    XCTAssert(data);
    XCTAssert(keyFileDigest);
    
    Kdb1Database* adaptor = [[Kdb1Database alloc] init];
    
    NSInputStream* stream = [NSInputStream inputStreamWithData:data];
    [stream open];
    
     [adaptor read:stream ckf:[CompositeKeyFactors password:nil keyFileDigest:keyFileDigest] completion:^(BOOL userCancelled, StrongboxDatabase * _Nullable db, NSError * _Nullable error) {
        [adaptor save:db completion:^(BOOL userCancelled, NSData * _Nullable saved, NSError * _Nullable error) {
            XCTAssert(saved);
             [adaptor read:[NSInputStream inputStreamWithData:saved] ckf:[CompositeKeyFactors password:nil keyFileDigest:keyFileDigest] completion:^(BOOL userCancelled, StrongboxDatabase * _Nullable reopened, NSError * _Nullable error) {
                XCTAssert(reopened);
                NSLog(@"%@", reopened);
            }];
        }];
    }];
 }

- (void)testKeePass2OpenSaveOpen {
    NSData *data = [CommonTesting getDataFromBundleFile:@"kp2-keyfile-only" ofType:@"kdbx"];
    NSData *keyFileDigest = [CommonTesting getDataFromBundleFile:@"ferrari" ofType:@"jpg"].sha256;
    
    XCTAssert(data);
    XCTAssert(keyFileDigest);
    
    KeePassDatabase* adaptor = [[KeePassDatabase alloc] init];

    NSInputStream* stream = [NSInputStream inputStreamWithData:data];
    [stream open];
    
     [adaptor read:stream
               ckf:[CompositeKeyFactors password:nil keyFileDigest:keyFileDigest] completion:^(BOOL userCancelled, StrongboxDatabase * _Nullable db, NSError * _Nullable error) {
        [adaptor save:db completion:^(BOOL userCancelled, NSData * _Nullable saved, NSError * _Nullable error) {
            XCTAssert(saved);
            NSInputStream* s2 = [NSInputStream inputStreamWithData:saved];
            [s2 open];
            
             [adaptor read:s2 ckf:[CompositeKeyFactors password:nil keyFileDigest:keyFileDigest] completion:^(BOOL userCancelled, StrongboxDatabase * _Nullable reopened, NSError * _Nullable error) {
                XCTAssert(reopened);
                NSLog(@"%@", reopened);
            }];
        }];
    }];
}

@end

