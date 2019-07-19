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
    NSData *safeData = [[NSFileManager defaultManager] contentsAtPath:@"/Users/mark/Google Drive/strongbox/keepass/favicon-test2.kdbx"];
    
    NSError* error;
    //Kdbx4Database *db = [[Kdbx4Database alloc] initExistingWithDataAndPassword:safeData password:@"a" error:&error];
    StrongboxDatabase* db = [[[Kdbx4Database alloc] init] open:safeData compositeKeyFactors:[CompositeKeyFactors password:@"a"] error:&error];
    NSLog(@"%@", db);
    
    XCTAssertNotNil(db);
}

@end
