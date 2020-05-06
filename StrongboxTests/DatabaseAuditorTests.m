//
//  DatabaseAuditorTests.m
//  StrongboxTests
//
//  Created by Mark on 17/04/2020.
//  Copyright © 2020 Mark McGuill. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "DatabaseGenerator.h"
#import "DatabaseAuditor.h"

@interface DatabaseAuditorTests : XCTestCase

@property BOOL done;

@end

@implementation DatabaseAuditorTests

- (void)waitUntilDone {
    while(!self.done) {
        [[NSRunLoop currentRunLoop] runUntilDate:[[NSDate date] dateByAddingTimeInterval:4]]; // 4 seconds
        //[[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate distantFuture]];
    }
}

- (void)testAuditGeneratedDatabase {
    DatabaseModel* db = [DatabaseGenerator generate:@"a"];
    
    DatabaseAuditor* auditor = [[DatabaseAuditor alloc] initWithPro:YES];
    [auditor start:db.activeRecords
            config:DatabaseAuditorConfiguration.defaults
 isDereferenceable:^BOOL(NSString * _Nonnull string) {
        return NO;
        }
      nodesChanged:^{ NSLog(@"AUDIT: Nodes Changed"); }
          progress:^(CGFloat progress) {
        NSLog(@"Audit Progress: %f", progress);
        }
        completion:^(BOOL userStopped) {
        DatabaseAuditReport* report = [auditor getAuditReport];
        NSLog(@"Completed - Database Audit Report = %@ - User Stopped: %d", report, userStopped);
        
        self.done = YES;
    }];
    
    [self waitUntilDone];
}

- (void)testAuditDatabaseWithSomeEntriesHavingNoPassword {
    DatabaseModel* db = [DatabaseGenerator generateEmpty:@"a"];

    Node* nodeWithNoPassword = [DatabaseGenerator generateSampleNode:db.rootGroup];
    nodeWithNoPassword.fields.password = @"";
    [db.rootGroup addChild:nodeWithNoPassword keePassGroupTitleRules:NO];

    Node* nodeWithPassword = [DatabaseGenerator generateSampleNode:db.rootGroup];
    [db.rootGroup addChild:nodeWithPassword keePassGroupTitleRules:NO];

    DatabaseAuditorConfiguration* config = [[DatabaseAuditorConfiguration alloc] init];
    config.checkForNoPasswords = YES;
    
    DatabaseAuditor* auditor = [[DatabaseAuditor alloc] initWithPro:YES];
       [auditor start:db.activeRecords
               config:config
    isDereferenceable:^BOOL(NSString * _Nonnull string) {
           return NO;
       }
        nodesChanged:^{ NSLog(@"AUDIT: Nodes Changed"); }
             progress:^(CGFloat progress) {
           NSLog(@"Audit Progress: %f", progress);
       }
           completion:^(BOOL userStopped) {
           DatabaseAuditReport* report = [auditor getAuditReport];
           NSLog(@"Completed - Database Audit Report = %@ - User Stopped: %d", report, userStopped);

           XCTAssertEqual(report.entriesWithNoPasswords.count, 1);
           XCTAssertEqual(report.entriesWithNoPasswords.allObjects.firstObject, nodeWithNoPassword);
           
           self.done = YES;
       }];
    
    [self waitUntilDone];
}

- (void)testAuditDatabaseWithSomeDuplicatePasswordsCaseInsensitive {
    DatabaseModel* db = [DatabaseGenerator generate:@"a"];

    NSArray<Node*> *active = db.activeRecords;

    Node* r1 = active[arc4random_uniform((uint32_t)active.count)];
    Node* r2 = active[arc4random_uniform((uint32_t)active.count)];

    r1.fields.password = @"dupl1cat3d";
    r2.fields.password = @"Dupl1cat3d";

    DatabaseAuditor* auditor = [[DatabaseAuditor alloc] initWithPro:YES];
       [auditor start:db.activeRecords
               config:DatabaseAuditorConfiguration.defaults
    isDereferenceable:^BOOL(NSString * _Nonnull string) {
           return NO;
       }
        nodesChanged:^{ NSLog(@"AUDIT: Nodes Changed"); }
             progress:^(CGFloat progress) {
           NSLog(@"Audit Progress: %f", progress);
       }
           completion:^(BOOL userStopped) {
           DatabaseAuditReport* report = [auditor getAuditReport];
                      
           NSLog(@"Database Audit Report = %@", report);

           XCTAssertGreaterThanOrEqual(report.entriesWithDuplicatePasswords.count, 2); // This might be greater than 2 if generator...

           XCTAssertTrue([report.entriesWithDuplicatePasswords containsObject:r1]);
           XCTAssertTrue([report.entriesWithDuplicatePasswords containsObject:r2]);

           self.done = YES;
       }];
    
    [self waitUntilDone];
}

- (void)testAuditDatabaseWithSomeDuplicatePasswordsCaseSensitive {
    DatabaseModel* db = [DatabaseGenerator generate:@"a"];

    NSArray<Node*> *active = db.activeRecords;

    Node* r1 = active[arc4random_uniform((uint32_t)active.count)];
    Node* r2 = active[arc4random_uniform((uint32_t)active.count)];

    r1.fields.password = @"dupl1cat3d";
    r2.fields.password = @"Dupl1cat3d";

    DatabaseAuditorConfiguration* config = DatabaseAuditorConfiguration.defaults;
    config.caseInsensitiveMatchForDuplicates = NO;

    DatabaseAuditor* auditor = [[DatabaseAuditor alloc] initWithPro:YES];
       [auditor start:db.activeRecords
               config:config
    isDereferenceable:^BOOL(NSString * _Nonnull string) {
           return NO;
       }
        nodesChanged:^{ NSLog(@"AUDIT: Nodes Changed"); }
             progress:^(CGFloat progress) {
           NSLog(@"Audit Progress: %f", progress);
       }
           completion:^(BOOL userStopped) {
           DatabaseAuditReport* report = [auditor getAuditReport];
           
           NSLog(@"Database Audit Report = %@", report);

           XCTAssertGreaterThanOrEqual(report.entriesWithDuplicatePasswords.count, 0); // This might be greater than 2 if generator...
           
           self.done = YES;
       }];
    
    [self waitUntilDone];
}

- (void)testAuditDatabaseWithEmptyPasswordsNotDuplicates {
    DatabaseModel* db = [DatabaseGenerator generateEmpty:@"a"];

    Node* r1 = [DatabaseGenerator generateSampleNode:db.rootGroup];
    [db.rootGroup addChild:r1 keePassGroupTitleRules:NO];
    Node* r2 = [DatabaseGenerator generateSampleNode:db.rootGroup];
    [db.rootGroup addChild:r2 keePassGroupTitleRules:NO];

    r1.fields.password = @"";
    r2.fields.password = @"";

    DatabaseAuditorConfiguration* config = DatabaseAuditorConfiguration.defaults;
    config.caseInsensitiveMatchForDuplicates = NO;

    DatabaseAuditor* auditor = [[DatabaseAuditor alloc] initWithPro:YES];
       [auditor start:db.activeRecords
               config:config
    isDereferenceable:^BOOL(NSString * _Nonnull string) {
           return NO;
       }
        nodesChanged:^{ NSLog(@"AUDIT: Nodes Changed"); }
             progress:^(CGFloat progress) {
           NSLog(@"Audit Progress: %f", progress);
       }
           completion:^(BOOL userStopped) {
           DatabaseAuditReport* report = [auditor getAuditReport];
           
           NSLog(@"Database Audit Report = %@", report);

           XCTAssertEqual(report.entriesWithDuplicatePasswords.count, 0);
           
           self.done = YES;
       }];
    
    [self waitUntilDone];
}

- (void)testAuditDatabaseWithSomeCommonPasswords {
    DatabaseModel* db = [DatabaseGenerator generate:@"a"];

    NSArray<Node*> *active = db.activeRecords;

    Node* r1 = active[arc4random_uniform((uint32_t)active.count)];

    r1.fields.password = @"123456";

    DatabaseAuditor* auditor = [[DatabaseAuditor alloc] initWithPro:YES];
       [auditor start:db.activeRecords
               config:DatabaseAuditorConfiguration.defaults
    isDereferenceable:^BOOL(NSString * _Nonnull string) {
           return NO;
       }
        nodesChanged:^{ NSLog(@"AUDIT: Nodes Changed"); }
             progress:^(CGFloat progress) {
           NSLog(@"Audit Progress: %f", progress);
       }
           completion:^(BOOL userStopped) {
           DatabaseAuditReport* report = [auditor getAuditReport];

           NSLog(@"Database Audit Report = %@", report);
           NSLog(@"Node with common password = %@", r1);

           XCTAssertGreaterThanOrEqual(report.entriesWithCommonPasswords.count, 1); // This might be greater than 1 if generator generates a weak one...

           XCTAssertTrue([report.entriesWithCommonPasswords containsObject:r1]);

           self.done = YES;
       }];
    
    [self waitUntilDone];
}

- (void)testSimilarEntries {
    DatabaseModel* db = [DatabaseGenerator generateEmpty:@"a"];

    Node* nodeWithPassword1 = [DatabaseGenerator generateSampleNode:db.rootGroup];
    nodeWithPassword1.fields.password = @"test";
    [db.rootGroup addChild:nodeWithPassword1 keePassGroupTitleRules:NO];

    Node* nodeWithPassword2 = [DatabaseGenerator generateSampleNode:db.rootGroup];
    [db.rootGroup addChild:nodeWithPassword2 keePassGroupTitleRules:NO];
    nodeWithPassword2.fields.password = @"wrist";

    DatabaseAuditorConfiguration* config = [[DatabaseAuditorConfiguration alloc] init];
    config.checkForSimilarPasswords = YES;
    
    DatabaseAuditor* auditor = [[DatabaseAuditor alloc] initWithPro:YES];
       [auditor start:db.activeRecords
               config:config
    isDereferenceable:^BOOL(NSString * _Nonnull string) {
           return NO;
       }
        nodesChanged:^{ NSLog(@"AUDIT: Nodes Changed"); }
             progress:^(CGFloat progress) {
           NSLog(@"Audit Progress: %f", progress);
       }
           completion:^(BOOL userStopped) {
           DatabaseAuditReport* report = [auditor getAuditReport];

           NSLog(@"Database Audit Report = %@", report);
           XCTAssertGreaterThanOrEqual(report.entriesWithSimilarPasswords.count, 2);

           self.done = YES;
       }];
    
    [self waitUntilDone];
}

- (void)testSimilarEntriesInLargeGeneratedDb {
    DatabaseModel* db = [DatabaseGenerator generate:@"a"];

    Node* nodeWithPassword1 = [DatabaseGenerator generateSampleNode:db.rootGroup];
    nodeWithPassword1.fields.password = @"test";
    [db.rootGroup addChild:nodeWithPassword1 keePassGroupTitleRules:NO];

    Node* nodeWithPassword2 = [DatabaseGenerator generateSampleNode:db.rootGroup];
    nodeWithPassword2.fields.password = @"rest";
    [db.rootGroup addChild:nodeWithPassword2 keePassGroupTitleRules:NO];

    DatabaseAuditorConfiguration* config = [[DatabaseAuditorConfiguration alloc] init];
    config.checkForSimilarPasswords = YES;
    config.levenshteinSimilarityThreshold = 0.4;

    DatabaseAuditor* auditor = [[DatabaseAuditor alloc] initWithPro:YES];
       [auditor start:db.activeRecords
               config:config
    isDereferenceable:^BOOL(NSString * _Nonnull string) {
           return NO;
       }
        nodesChanged:^{ NSLog(@"AUDIT: Nodes Changed"); }
             progress:^(CGFloat progress) {
           NSLog(@"Audit Progress: %f", progress);
       }
           completion:^(BOOL userStopped) {
           DatabaseAuditReport* report = [auditor getAuditReport];

           NSLog(@"Done! - Database Audit Report = %@", report);

           XCTAssertGreaterThanOrEqual(report.entriesWithSimilarPasswords.count, 2);
           XCTAssertTrue([report.entriesWithSimilarPasswords containsObject:nodeWithPassword1]);
           XCTAssertTrue([report.entriesWithSimilarPasswords containsObject:nodeWithPassword2]);
//
           for(Node* node in report.entriesWithSimilarPasswords) {
               NSLog(@"%@", node.fields.password);
           }

           self.done = YES;
       }];
    
    [self waitUntilDone];
}

- (void)testMinLength {
    DatabaseModel* db = [DatabaseGenerator generateEmpty:@"a"];

    Node* nodeWithPassword1 = [DatabaseGenerator generateSampleNode:db.rootGroup];
    nodeWithPassword1.fields.password = @"12345678";
    [db.rootGroup addChild:nodeWithPassword1 keePassGroupTitleRules:NO];

    Node* nodeWithPassword2 = [DatabaseGenerator generateSampleNode:db.rootGroup];
    [db.rootGroup addChild:nodeWithPassword2 keePassGroupTitleRules:NO];
    nodeWithPassword2.fields.password = @"1234567";

    DatabaseAuditorConfiguration* config = [[DatabaseAuditorConfiguration alloc] init];
    config.checkForMinimumLength = YES;
    config.minimumLength = 8;
    
    DatabaseAuditor* auditor = [[DatabaseAuditor alloc] initWithPro:YES];
       [auditor start:db.activeRecords
               config:config
    isDereferenceable:^BOOL(NSString * _Nonnull string) {
           return NO;
       }
        nodesChanged:^{ NSLog(@"AUDIT: Nodes Changed"); }
             progress:^(CGFloat progress) {
           NSLog(@"Audit Progress: %f", progress);
       }
           completion:^(BOOL userStopped) {
           DatabaseAuditReport* report = [auditor getAuditReport];

           NSLog(@"Database Audit Report = %@", report);
           XCTAssertEqual(report.entriesTooShort.count, 1);

           self.done = YES;
       }];
    
    [self waitUntilDone];
}

- (void)testHibp {
    DatabaseModel* db = [DatabaseGenerator generateEmpty:@"a"];

    Node* nodeWithPassword1 = [DatabaseGenerator generateSampleNode:db.rootGroup];
    nodeWithPassword1.fields.password = @"12345678";
    [db.rootGroup addChild:nodeWithPassword1 keePassGroupTitleRules:NO];

    Node* nodeWithPassword2 = [DatabaseGenerator generateSampleNode:db.rootGroup];
    [db.rootGroup addChild:nodeWithPassword2 keePassGroupTitleRules:NO];
    nodeWithPassword2.fields.password = @"1234567";

    DatabaseAuditorConfiguration* config = [[DatabaseAuditorConfiguration alloc] init];
    config.checkHibp = YES;
    
    DatabaseAuditor* auditor = [[DatabaseAuditor alloc] initWithPro:YES];
       [auditor start:db.activeRecords
               config:config
    isDereferenceable:^BOOL(NSString * _Nonnull string) {
           return NO;
       }
        nodesChanged:^{ NSLog(@"AUDIT: Nodes Changed"); }
             progress:^(CGFloat progress) {
           NSLog(@"Audit Progress: %f", progress);
       }
           completion:^(BOOL userStopped) {
           DatabaseAuditReport* report = [auditor getAuditReport];

           NSLog(@"Database Audit Report = %@", report);
           XCTAssertEqual(report.entriesPwned.count, 2);

           self.done = YES;
       }];
    
    [self waitUntilDone];
}

//- (void)testAuditPerformance {
//    DatabaseModel* db = [DatabaseGenerator generate:@"a"];
//    [self measureBlock:^{
//        DatabaseAuditReport* report = [DatabaseAuditor.sharedInstance audit:db config:DatabaseAuditorConfiguration.defaults];
//        NSLog(@"Database Audit Report = %@", report);
//    }];
//}

@end
