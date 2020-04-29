//
//  KdbxHistory.m
//  StrongboxTests
//
//  Created by Mark on 07/03/2019.
//  Copyright © 2019 Mark McGuill. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "CommonTesting.h"
#import "KeePassConstants.h"
#import "DatabaseModel.h"
#import "KeePassDatabase.h"
#import "Kdbx4Database.h"

@interface KdbxHistory : XCTestCase

@end

@implementation KdbxHistory

- (void)testGoogleDriveSafeWithHistory {
    NSData *safeData = [[NSFileManager defaultManager] contentsAtPath:@"/Users/strongbox/strongbox-test-files/favicon-test2.kdbx"];

    [[[Kdbx4Database alloc] init] open:safeData
                                   ckf:[CompositeKeyFactors password:@"a"]
                            completion:^(BOOL userCancelled, StrongboxDatabase * _Nullable db, NSError * _Nullable error) {
        NSLog(@"%@", db);
        XCTAssertNotNil(db);
    }];
}

@end
