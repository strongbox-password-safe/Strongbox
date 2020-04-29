//
//  TagsTests.m
//  StrongboxTests
//
//  Created by Mark on 23/03/2020.
//  Copyright © 2020 Mark McGuill. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "KeePassDatabase.h"

@interface TagsTests : XCTestCase

@end

@implementation TagsTests

- (void)testExample {
    NSString *path = @"/Users/strongbox/strongbox-test-files/tags.kdbx";    
    NSData *safeData = [[NSFileManager defaultManager] contentsAtPath:path];

    XCTAssertNotNil(safeData);
    
    [[[KeePassDatabase alloc] init] open:safeData
                                     ckf:[CompositeKeyFactors password:@"a"]
                              completion:^(BOOL userCancelled, StrongboxDatabase * _Nullable db, NSError * _Nullable error) {
        NSLog(@"%@", db);
        XCTAssertNotNil(db);
    }];
}

- (void)testCreate {
    StrongboxDatabase* dbInit = [[[KeePassDatabase alloc] init] create:[CompositeKeyFactors password:@"a"]];

    Node* actualRoot = dbInit.rootGroup.children[0];
    
    Node* node = [[Node alloc] initAsRecord:@"Foo" parent:actualRoot];
    [node.fields.tags addObject:@"tag-1"];
    [node.fields.tags addObject:@"tag-2"];
    [actualRoot addChild:node keePassGroupTitleRules:YES];

    XCTAssertNotNil(dbInit);

    NSLog(@"%@", node.fields.tags);

    [[[KeePassDatabase alloc] init] save:dbInit
                              completion:^(BOOL userCancelled, NSData * _Nullable data, NSError * _Nullable error) {
        XCTAssertNotNil(data);
        
        [[[KeePassDatabase alloc] init] open:data
                                         ckf:[CompositeKeyFactors password:@"a"]
                                  completion:^(BOOL userCancelled, StrongboxDatabase * _Nullable db, NSError * _Nullable error) {
            NSLog(@"%@", db);
            
            Node* recreated = db.rootGroup.children[0].children[0];
            XCTAssertNotNil(db);
            
            NSLog(@"%@ -> %@", recreated.fields.tags, node.fields.tags);
            XCTAssertTrue([recreated.fields.tags isEqualToSet:node.fields.tags]);
        }];
    }];
}

@end
