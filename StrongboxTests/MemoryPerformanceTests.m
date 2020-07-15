//
//  MemoryPerformanceTests.m
//  StrongboxTests
//
//  Created by Mark on 03/09/2019.
//  Copyright © 2019 Mark McGuill. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "Kdbx4Database.h"
#import "CommonTesting.h"
#import "KeePassDatabase.h"

@interface MemoryPerformanceTests : XCTestCase

@end

@implementation MemoryPerformanceTests

- (void)testExample {
    int groupCount = 100;
    int subGroupCount = 10;
    int entryCount = 100;

    StrongboxDatabase *db = [[Kdbx4Database alloc] create:[CompositeKeyFactors password:@"a"]];
    
    Node* keePassRoot = db.rootGroup.children.firstObject;
    
    for(int i=0;i<groupCount;i++) {
        for(int k=0;k<subGroupCount;k++) {
            NSString* groupName = [NSString stringWithFormat:@"Group-%d.%d", i, k];
            Node* childGroup = [[Node alloc] initAsGroup:groupName parent:keePassRoot keePassGroupTitleRules:NO uuid:nil];
            
            [keePassRoot addChild:childGroup keePassGroupTitleRules:NO];
            
            for (int j = 0; j < entryCount; j++) {
                Node* childEntry = [self createSampleEntry:j parentGroup:childGroup];
                [childGroup addChild:childEntry keePassGroupTitleRules:YES];
            }
        }
    }
    
    [[Kdbx4Database alloc] save:db completion:^(BOOL userCancelled, NSData * _Nullable largeDb, NSError * _Nullable error) {
        NSString* filename = [NSString stringWithFormat:@"large-%d-%d-%d.kdbx", groupCount, subGroupCount, entryCount];
        NSString* file = [NSTemporaryDirectory() stringByAppendingPathComponent:filename];
        
        BOOL success = [largeDb writeToFile:file options:kNilOptions error:&error];
        
        NSLog(@"Done: %d [%@] [%@]", success, error, file);
    }];
}

- (void)testReadLarge {
    NSInputStream* stream = [NSInputStream inputStreamWithFileAtPath:@"/Users/strongbox/strongbox-test-files/large-test-242-3.1.kdbx"];
    [stream open];
    [[KeePassDatabase alloc] read:stream ckf:[CompositeKeyFactors password:@"a"] completion:^(BOOL userCancelled, StrongboxDatabase * _Nullable db, NSError * _Nullable error) {
        XCTAssertNil(error);
        XCTAssertNotNil(db);
        NSLog(@"Done... [%@]", error);
    }];
}

- (Node*)createSampleEntry:(int)index parentGroup:(Node*)parentGroup {
    NodeFields *fields = [[NodeFields alloc] initWithUsername:[NSString stringWithFormat:@"user-%d", index]
                                                          url:[NSString stringWithFormat:@"https://www.website-%d.com/path", index]
                                                     password:[NSString stringWithFormat:@"passw0rd-%d", index]
                                                        notes:[NSString stringWithFormat:@"notes could be quite long too-%d", index]
                                                        email:[NSString stringWithFormat:@"mark-%d@gmail.com", index]];
    
    Node* childEntry = [[Node alloc] initAsRecord:@(index).stringValue parent:parentGroup fields:fields uuid:nil];
    
    // FUTURE: Add Custom Fields, Dates, Attachments, Expiry, Icons, Custom Icons, etc
    
    return childEntry;
}

@end
