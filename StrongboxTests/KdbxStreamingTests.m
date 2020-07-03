//
//  KdbxStreamingTests.m
//  StrongboxTests
//
//  Created by Strongbox on 13/06/2020.
//  Copyright © 2020 Mark McGuill. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "KeePassDatabase.h"

@interface KdbxStreamingTests : XCTestCase

@end

@implementation KdbxStreamingTests

- (void)testLargeAesFile {
    NSData *largeDb = [[NSFileManager defaultManager] contentsAtPath:@"/Users/strongbox/strongbox-test-files/large-test-242-3.1.kdbx"];
    XCTAssertNotNil(largeDb);
    
    NSInputStream* stream = [NSInputStream inputStreamWithData:largeDb];
    [stream open];
    
    [[[KeePassDatabase alloc] init] read:stream
                                     ckf:[CompositeKeyFactors password:@"a"]
                              completion:^(BOOL userCancelled, StrongboxDatabase * _Nullable db, NSError * _Nullable error) {
        NSLog(@"%@", db);
        XCTAssertNotNil(db);
        XCTAssertTrue([db.rootGroup.children[0].title isEqualToString:@"Database"]);
    }];
}

- (void)testLargeTwoFishFile {
    NSData *largeDb = [[NSFileManager defaultManager] contentsAtPath:@"/Users/strongbox/strongbox-test-files/large-test-242-3.1-TwoFish.kdbx"];
    XCTAssertNotNil(largeDb);
    
    NSInputStream* stream = [NSInputStream inputStreamWithData:largeDb];
    [stream open];
    
    [[[KeePassDatabase alloc] init] read:stream
                                     ckf:[CompositeKeyFactors password:@"a"]
                              completion:^(BOOL userCancelled, StrongboxDatabase * _Nullable db, NSError * _Nullable error) {
        NSLog(@"%@", db);
        XCTAssertNotNil(db);
        XCTAssertTrue([db.rootGroup.children[0].title isEqualToString:@"Database"]);
    }];
}

- (void)tstLargeChaCha20File { // NB: THis is broken in legacy as well as streamed... just not supported but keepassxc can support it?
    NSData *largeDb = [[NSFileManager defaultManager] contentsAtPath:@"/Users/strongbox/strongbox-test-files/large-test-242-3.1-ChaCha20.kdbx"];
    XCTAssertNotNil(largeDb);
    
    NSInputStream* stream = [NSInputStream inputStreamWithData:largeDb];
    [stream open];
    
    [[[KeePassDatabase alloc] init] read:stream
                                     ckf:[CompositeKeyFactors password:@"a"]
                              completion:^(BOOL userCancelled, StrongboxDatabase * _Nullable db, NSError * _Nullable error) {
        NSLog(@"%@ - error = [%@]", db, error);
        XCTAssertNotNil(db);
        XCTAssertTrue([db.rootGroup.children[0].title isEqualToString:@"Database"]);
    }];
}

@end
