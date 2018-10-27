//
//  KeePassDatabaseTests.m
//  StrongboxTests
//
//  Created by Mark on 23/10/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "CommonTesting.h"
#import "KeePassDatabase.h"

@interface KeePassDatabaseTests : XCTestCase

@end

@implementation KeePassDatabaseTests

- (void)testInitExistingWithAllKdbxTestFiles {
    for (NSString* file in CommonTesting.testKdbxFilesAndPasswords) {
        NSLog(@"=============================================================================================================");
        NSLog(@"===================================== %@ ===============================================", file);

        NSData *blob = [CommonTesting getDataFromBundleFile:file ofType:@"kdbx"];
        
        NSError* error;
        NSString* password = [CommonTesting.testKdbxFilesAndPasswords objectForKey:file];
        
        KeePassDatabase *db = [[KeePassDatabase alloc] initExistingWithDataAndPassword:blob password:password error:&error];

        XCTAssertNotNil(db);

        NSLog(@"%@", db);
        NSLog(@"=============================================================================================================");
    }
}

- (void)testInitExistingWithATestFile {
    NSData *blob = [CommonTesting getDataFromBundleFile:@"a" ofType:@"kdbx"];
    NSError* error;
    KeePassDatabase *db = [[KeePassDatabase alloc] initExistingWithDataAndPassword:blob password:@"a" error:&error];
    
    XCTAssertNotNil(db);
    
    NSLog(@"%@", db);

    XCTAssert(db.rootGroup.childGroups.count == 1);
    XCTAssert([[db.rootGroup.childGroups objectAtIndex:0].title isEqualToString:@"General"]);
    XCTAssert([[[db.rootGroup.childGroups objectAtIndex:0].childGroups objectAtIndex:4].title isEqualToString:@"New Group"]);
    XCTAssert([[[[db.rootGroup.childGroups objectAtIndex:0].childGroups objectAtIndex:4].childRecords objectAtIndex:0].fields.password isEqualToString:@"ladder"]);
}

- (void)testInitExistingWithCustomAndBinariesFile {
    NSData *blob = [CommonTesting getDataFromBundleFile:@"Database" ofType:@"kdbx"];
    NSError* error;
    KeePassDatabase *db = [[KeePassDatabase alloc] initExistingWithDataAndPassword:blob password:@"a" error:&error];
    
    XCTAssertNotNil(db);
}

- (void)testInitExistingWithGoogleDriveSafe {
    NSData *safeData = [[NSFileManager defaultManager] contentsAtPath:@"/Users/mark/Google Drive/strongbox/keepass/1.kdbx"];
    NSError* error;
    KeePassDatabase *db = [[KeePassDatabase alloc] initExistingWithDataAndPassword:safeData password:@"a" error:&error];
    
    NSLog(@"%@", db);
    
    XCTAssertNotNil(db);
}



- (void)testInitNew {
    KeePassDatabase* db = [[KeePassDatabase alloc] initNewWithPassword:@"password"];

    NSLog(@"%@", db);
    
    XCTAssert([[db.rootGroup.childGroups objectAtIndex:0].title isEqualToString:kDefaultRootGroupName]);
    XCTAssert([db.metadata.generator isEqualToString:@"Strongbox"]);
    XCTAssert(db.metadata.compressionFlags == kGzipCompressionFlag);
}

- (void)testEmptyDbGetAsDataAndReOpenSafeIsTheSame {
    KeePassDatabase* db = [[KeePassDatabase alloc] initNewWithPassword:@"password"];
    
    NSLog(@"%@", db);
    
    XCTAssert([[db.rootGroup.childGroups objectAtIndex:0].title isEqualToString:kDefaultRootGroupName]);
    XCTAssert([db.metadata.generator isEqualToString:@"Strongbox"]);
    XCTAssert(db.metadata.compressionFlags == kGzipCompressionFlag);

    NSError* error;
    NSData* data = [db getAsData:&error];

    if(error) {
        NSLog(@"%@", error);
    }
    
    XCTAssertNil(error);
    XCTAssertNotNil(data);
 
    KeePassDatabase *b = [[KeePassDatabase alloc] initExistingWithDataAndPassword:data password:@"password" error:&error];
    
    if(error) {
        NSLog(@"%@", error);
    }
    
    XCTAssertNotNil(b);
 
    NSLog(@"%@", b);

    XCTAssert([[b.rootGroup.childGroups objectAtIndex:0].title isEqualToString:kDefaultRootGroupName]);
    XCTAssert([b.metadata.generator isEqualToString:@"Strongbox"]);
    XCTAssert(b.metadata.compressionFlags == kGzipCompressionFlag);
}

- (void)testOpenSaveOpenWithAllKdbxTestFiles {
    for (NSString* file in CommonTesting.testKdbxFilesAndPasswords) {
        NSLog(@"=============================================================================================================");
        NSLog(@"===================================== %@ ===============================================", file);
        
        NSData *blob = [CommonTesting getDataFromBundleFile:file ofType:@"kdbx"];
        
        NSError* error;
        NSString* password = [CommonTesting.testKdbxFilesAndPasswords objectForKey:file];
        
        KeePassDatabase *db = [[KeePassDatabase alloc] initExistingWithDataAndPassword:blob password:password error:&error];
        
        XCTAssertNotNil(db);
        
        //NSLog(@"%@", db);
        NSLog(@"=============================================================================================================");
    
        NSData* data = [db getAsData:&error];
        
        if(error) {
            NSLog(@"%@", error);
        }
        
        XCTAssertNil(error);
        XCTAssertNotNil(data);
        
        KeePassDatabase *b = [[KeePassDatabase alloc] initExistingWithDataAndPassword:data password:password error:&error];
        
        if(error) {
            NSLog(@"%@", error);
        }
        
        XCTAssertNotNil(b);
        
        //NSLog(@"%@", b);
    }
}

- (void)testDbModifyWithEscapeCharacterGetAsDataAndReOpenSafeIsTheSame {
    KeePassDatabase* db = [[KeePassDatabase alloc] initNewWithPassword:@"password"];
    
    NSLog(@"%@", db);
    
    XCTAssert([[db.rootGroup.childGroups objectAtIndex:0].title isEqualToString:kDefaultRootGroupName]);
    XCTAssert([db.metadata.generator isEqualToString:@"Strongbox"]);
    XCTAssert(db.metadata.compressionFlags == kGzipCompressionFlag);
    
    NodeFields *fields = [[NodeFields alloc] init];
    Node *childNode = [[Node alloc] initAsRecord:@"Title &<>'\\ Done" parent:[db.rootGroup.childGroups objectAtIndex:0] fields:fields uuid:nil];
    [[db.rootGroup.childGroups objectAtIndex:0] addChild:childNode];
    
    NSError* error;
    NSData* data = [db getAsData:&error];
    
    if(error) {
        NSLog(@"%@", error);
    }
    
    XCTAssertNil(error);
    XCTAssertNotNil(data);
    
    KeePassDatabase *b = [[KeePassDatabase alloc] initExistingWithDataAndPassword:data password:@"password" error:&error];
    
    if(error) {
        NSLog(@"%@", error);
    }
    
    XCTAssertNotNil(b);
    
    NSLog(@"%@", b);
    
    XCTAssert([[b.rootGroup.childGroups objectAtIndex:0].title isEqualToString:kDefaultRootGroupName]);
    XCTAssert([b.metadata.generator isEqualToString:@"Strongbox"]);
    XCTAssert(b.metadata.compressionFlags == kGzipCompressionFlag);

    XCTAssert([[[[b.rootGroup.childGroups objectAtIndex:0] childRecords] objectAtIndex:0].title isEqualToString:@"Title &<>'\\ Done"]);
}


@end
