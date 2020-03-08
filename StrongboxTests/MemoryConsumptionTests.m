//
//  MemoryConsumptionTests.m
//  StrongboxTests
//
//  Created by Mark on 29/08/2019.
//  Copyright © 2019 Mark McGuill. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "Kdbx4Database.h"

@interface MemoryConsumptionTests : XCTestCase

@end

@implementation MemoryConsumptionTests

- (void)testExample {
    int entryCount = 100;
    NSArray* groupCounts = @[@(75)];
    
    for (NSNumber* groupCount in groupCounts) {
        StrongboxDatabase *db = [[Kdbx4Database alloc] create:[CompositeKeyFactors password:@"a"]];
    
        Node* keePassRoot = db.rootGroup.children.firstObject;
    
        for(int i=0;i<groupCount.intValue;i++) {
            Node* childGroup = [[Node alloc] initAsGroup:@(i).stringValue parent:keePassRoot keePassGroupTitleRules:NO uuid:nil];
            [keePassRoot addChild:childGroup keePassGroupTitleRules:NO];
            
            for (int j = 0; j < entryCount; j++) {
                NodeFields *fields = [[NodeFields alloc] initWithUsername:[NSString stringWithFormat:@"user-%d", j]
                                                                      url:[NSString stringWithFormat:@"https://www.website-%d.com/path", j]
                                                                 password:[NSString stringWithFormat:@"passw0rd-%d", j]
                                                                    notes:[NSString stringWithFormat:@"notes could be quite long too-%d", j]
                                                                    email:[NSString stringWithFormat:@"mark-%d@gmail.com", j]];
                
                Node* childEntry = [[Node alloc] initAsRecord:@(j).stringValue parent:childGroup fields:fields uuid:nil];
                [childGroup addChild:childEntry keePassGroupTitleRules:YES];
            }
        }
        
        [[Kdbx4Database alloc] save:db completion:^(BOOL userCancelled, NSData * _Nullable data, NSError * _Nullable error) {
            BOOL success = [data writeToFile:[NSString stringWithFormat:@"/Users/mark/Desktop/sample-%@g%d.kdbx", groupCount, entryCount]
                                     options:kNilOptions
                                       error:&error];
            
            NSLog(@"Done %d - [%@]", success, error);
        }];
    }
}

- (void)testEmptyExample {
    StrongboxDatabase *db = [[Kdbx4Database alloc] create:[CompositeKeyFactors password:@"a"]];
    
    Node* keePassRoot = db.rootGroup.children.firstObject;
    for(int i=0;i<75;i++) {
        Node* childGroup = [[Node alloc] initAsGroup:@(i).stringValue parent:keePassRoot keePassGroupTitleRules:NO uuid:nil];
        [keePassRoot addChild:childGroup keePassGroupTitleRules:NO];
        
        for (int j = 0; j < 100; j++) {
            Node* childEntry = [[Node alloc] initAsRecord:@(j).stringValue parent:childGroup];
            [childGroup addChild:childEntry keePassGroupTitleRules:YES];
        }
    }
    
    [[Kdbx4Database alloc] save:db  completion:^(BOOL userCancelled, NSData * _Nullable data, NSError * _Nullable error) {
        BOOL success = [data writeToFile:@"/Users/mark/Desktop/memory.kdbx" options:kNilOptions error:&error];
        NSLog(@"Done %d - [%@]", success, error);
    }];
}

@end
