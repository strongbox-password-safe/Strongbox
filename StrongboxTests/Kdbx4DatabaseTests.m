//
//  Kdbx4DatabaseTests.m
//  StrongboxTests
//
//  Created by Mark on 26/10/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "CommonTesting.h"
#import "Kdbx4Database.h"
#import "KeePassConstants.h"
#import "DatabaseModel.h"

@interface Kdbx4DatabaseTests : XCTestCase

@end

@implementation Kdbx4DatabaseTests

- (void)testInitExistingWithAllKdbxTestFiles {
    for (NSString* file in CommonTesting.testKdbx4FilesAndPasswords) {
        NSLog(@"=============================================================================================================");
        NSLog(@"===================================== %@ ===============================================", file);
        
        NSData *blob = [CommonTesting getDataFromBundleFile:file ofType:@"kdbx"];
        
        NSString* password = [CommonTesting.testKdbx4FilesAndPasswords objectForKey:file];
        
        NSInputStream* stream = [NSInputStream inputStreamWithData:blob];
        [stream open];
        [[[Kdbx4Database alloc] init] read:stream
                                       ckf:[CompositeKeyFactors password:password]
                                completion:^(BOOL userCancelled, StrongboxDatabase * _Nullable db, NSError * _Nullable error) {
            XCTAssertNotNil(db);
            
            NSLog(@"%@", db);
            NSLog(@"=============================================================================================================");
        }];
    }
}

- (void)testInitExistingWithLargeAGoogleDriveSafeUncompressed {
    NSData *safeData = [[NSFileManager defaultManager] contentsAtPath:@"/Users/strongbox/strongbox-test-files/Database-Large-Uncompressed.kdbx"];
    
    NSInputStream* stream = [NSInputStream inputStreamWithData:safeData];
    [stream open];
    [[[Kdbx4Database alloc] init] read:stream
                                   ckf:[CompositeKeyFactors password:@"a"]
                            completion:^(BOOL userCancelled, StrongboxDatabase * _Nullable db, NSError * _Nullable error) {
        NSLog(@"%@", db);
        XCTAssertNotNil(db);
    }];
}

- (void)testInitExistingWithLargeGoogleDriveSafe {
    NSData *safeData = [[NSFileManager defaultManager] contentsAtPath:@"/Users/strongbox/strongbox-test-files/Database-Large.kdbx"];

    NSInputStream* stream = [NSInputStream inputStreamWithData:safeData];
    [stream open];
    [[[Kdbx4Database alloc] init] read:stream
                                   ckf:[CompositeKeyFactors password:@"a"] completion:^(BOOL userCancelled, StrongboxDatabase * _Nullable db, NSError * _Nullable error) {
        NSLog(@"%@ - [%@]", db, error);
        XCTAssertNotNil(db);
    }];
}

- (void)testEmptyDbGetAsDataAndReOpenSafeIsTheSame {
    id<AbstractDatabaseFormatAdaptor> adaptor = [[Kdbx4Database alloc] init];
    StrongboxDatabase* db = [adaptor create:[CompositeKeyFactors password:@"password"]];
    
    NSLog(@"%@", db);
    
    XCTAssert([[db.rootGroup.childGroups objectAtIndex:0].title isEqualToString:kDefaultRootGroupName]);
    
    KeePass4DatabaseMetadata* metadata = db.metadata;
    XCTAssert([metadata.generator isEqualToString:@"Strongbox"]);
    XCTAssert(metadata.compressionFlags == kGzipCompressionFlag);
    
    [adaptor save:db completion:^(BOOL userCancelled, NSData * _Nullable data, NSError * _Nullable error) {
        if(error) {
            NSLog(@"%@", error);
        }
        
        XCTAssertNil(error);
        XCTAssertNotNil(data);

        NSInputStream* stream = [NSInputStream inputStreamWithData:data];
        [stream open];
        [adaptor read:stream
                  ckf:[CompositeKeyFactors password:@"password"]
           completion:^(BOOL userCancelled, StrongboxDatabase * _Nullable b, NSError * _Nullable error) {
            if(error) {
                NSLog(@"%@", error);
            }
            
            XCTAssertNotNil(b);
            
            NSLog(@"%@", b);
            
            KeePass4DatabaseMetadata* metadata = b.metadata;
            XCTAssert([[b.rootGroup.childGroups objectAtIndex:0].title isEqualToString:kDefaultRootGroupName]);
            XCTAssert([metadata.generator isEqualToString:@"Strongbox"]);
            XCTAssert(metadata.compressionFlags == kGzipCompressionFlag);
        }];
    }];
}

- (void)testSmallNewDbWithPasswordGetAsDataAndReOpenSafeIsTheSame {
    id<AbstractDatabaseFormatAdaptor> adaptor = [[Kdbx4Database alloc] init];

    StrongboxDatabase* db = [adaptor create:[CompositeKeyFactors password:@"password"]];

    KeePass4DatabaseMetadata* metadata = db.metadata;
    XCTAssert([[db.rootGroup.childGroups objectAtIndex:0].title isEqualToString:kDefaultRootGroupName]);
    XCTAssert([metadata.generator isEqualToString:@"Strongbox"]);
    XCTAssert(metadata.compressionFlags == kGzipCompressionFlag);
    
    Node* keePassRoot = [db.rootGroup.childGroups objectAtIndex:0];
    NSData* data1 = [@"This is attachment 1 UTF data" dataUsingEncoding:NSUTF8StringEncoding];
    NSData *data2 = [@"This is attachment 2 UTF data" dataUsingEncoding:NSUTF8StringEncoding];
    
    //

    NodeFields *fields = [[NodeFields alloc] initWithUsername:@"username" url:@"url" password:@"ladder" notes:@"notes" email:@"email"];
    
    Node* record = [[Node alloc] initAsRecord:@"Title" parent:keePassRoot fields:fields uuid:nil];
    [keePassRoot addChild:record keePassGroupTitleRules:YES];
        
    DatabaseAttachment* db1 = [[DatabaseAttachment alloc] initWithData:data1 compressed:YES protectedInMemory:YES];
    [db addNodeAttachment:record attachment:[[UiAttachment alloc] initWithFilename:@"attachment1.txt" dbAttachment:db1]];
    DatabaseAttachment* db2 = [[DatabaseAttachment alloc] initWithData:data2 compressed:YES protectedInMemory:YES];
    [db addNodeAttachment:record attachment:[[UiAttachment alloc] initWithFilename:@"attachment2.txt" dbAttachment:db2]];

    //NSLog(@"BEFORE: %@", db);
    
    [adaptor save:db completion:^(BOOL userCancelled, NSData * _Nullable data, NSError * _Nullable error) {
        if(error) {
            NSLog(@"%@", error);
        }
        
        XCTAssertNil(error);
        XCTAssertNotNil(data);
        
         NSInputStream* stream = [NSInputStream inputStreamWithData:data];
         [stream open];
         [adaptor read:stream
                  ckf:[CompositeKeyFactors password:@"password"]
           completion:^(BOOL userCancelled, StrongboxDatabase * _Nullable b, NSError * _Nullable error) {
            if(error) {
                NSLog(@"%@", error);
            }
            
            XCTAssertNotNil(b);
            
            //NSLog(@"AFTER: %@", b);
            
            KeePass4DatabaseMetadata* metadata = b.metadata;
            XCTAssert([[b.rootGroup.childGroups objectAtIndex:0].title isEqualToString:kDefaultRootGroupName]);
            XCTAssert([metadata.generator isEqualToString:@"Strongbox"]);
            XCTAssert(metadata.compressionFlags == kGzipCompressionFlag);

            Node* bKeePassRoot = b.rootGroup.childGroups[0];
            Node* bRecord = bKeePassRoot.childRecords[0];

            XCTAssert([bRecord.title isEqualToString:@"Title"]);
            XCTAssert(bRecord.fields.email.length == 0); // Email is ditched by KeePass
            
            XCTAssert([bRecord.fields.username isEqualToString:@"username"]);
            XCTAssert([bRecord.fields.url isEqualToString:@"url"]);
            XCTAssert([bRecord.fields.notes isEqualToString:@"notes"]);
            XCTAssert([bRecord.fields.password isEqualToString:@"ladder"]);
            
            XCTAssert(bRecord.fields.attachments.count == 2);

            XCTAssert([bRecord.fields.attachments[0].filename isEqualToString:@"attachment1.txt"]);
            XCTAssert([bRecord.fields.attachments[1].filename isEqualToString:@"attachment2.txt"]);
            XCTAssert(bRecord.fields.attachments[0].index == 0);
            XCTAssert(bRecord.fields.attachments[1].index == 1);

            XCTAssert(b.attachments.count == 2);

            XCTAssert([b.attachments[0].unitTestDataOnly isEqualToData:data1]);
            XCTAssert([b.attachments[1].unitTestDataOnly isEqualToData:data2]);
        }];
    }];
}

- (void)testKdbx4AesArgon2NonDefaultKdf {
    NSData *blob = [CommonTesting getDataFromBundleFile:@"Database-Aes-Argon2NonDefault" ofType:@"kdbx"];
    
    id<AbstractDatabaseFormatAdaptor> adaptor = [[Kdbx4Database alloc] init];
    
    NSInputStream* stream = [NSInputStream inputStreamWithData:blob];
    [stream open];
    [adaptor read:stream
               ckf:[CompositeKeyFactors password:@"a"] completion:^(BOOL userCancelled, StrongboxDatabase * _Nullable db, NSError * _Nullable error) {
        XCTAssertNotNil(db);
        
        NSLog(@"%@", db);
        
        Node* testNode = db.rootGroup.childGroups[0].childRecords[0];
        XCTAssert(testNode);
        XCTAssert([testNode.title isEqualToString:@"Sample Entry"]);
        XCTAssert([testNode.fields.username isEqualToString:@"User Name"]);
        XCTAssert([testNode.fields.password isEqualToString:@"Password"]);
    }];
}

- (void)disabledTestKdbx4AesArgon2NonDefaultKdfReadAndWrite {
    NSData *blob = [CommonTesting getDataFromBundleFile:@"Database-Aes-Argon2NonDefault" ofType:@"kdbx"];
    
    id<AbstractDatabaseFormatAdaptor> adaptor = [[Kdbx4Database alloc] init];
     
    NSInputStream* stream = [NSInputStream inputStreamWithData:blob];
    [stream open];
    [adaptor read:stream

               ckf:[CompositeKeyFactors password:@"a"]
        completion:^(BOOL userCancelled, StrongboxDatabase * _Nullable db, NSError * _Nullable error) {
        XCTAssertNotNil(db);
        
        NSLog(@"BEFORE: %@", db);

        [adaptor save:db completion:^(BOOL userCancelled, NSData * _Nullable data, NSError * _Nullable error) {
            XCTAssert(data);
            
             [adaptor read:[NSInputStream inputStreamWithData:data]
                      ckf:[CompositeKeyFactors password:@"a"]
               completion:^(BOOL userCancelled, StrongboxDatabase * _Nullable db2, NSError * _Nullable error) {
                NSLog(@"AFTER: %@", db2);

                Node* testNode = db2.rootGroup.childGroups[0].childRecords[0];
                XCTAssert(testNode);
                XCTAssert([testNode.title isEqualToString:@"Sample Entry"]);
                XCTAssert([testNode.fields.username isEqualToString:@"User Name"]);
                XCTAssert([testNode.fields.password isEqualToString:@"Password"]);
            }];
        }];
    }];
}

- (void)testCustomIcon {
    NSData *blob = [CommonTesting getDataFromBundleFile:@"custom-icon-4" ofType:@"kdbx"];
    
    id<AbstractDatabaseFormatAdaptor> adaptor = [[Kdbx4Database alloc] init];
    NSInputStream* stream = [NSInputStream inputStreamWithData:blob];
    [stream open];
    
    [adaptor read:stream
               ckf:[CompositeKeyFactors password:@"a"]
       completion:^(BOOL userCancelled, StrongboxDatabase * _Nullable db, NSError * _Nullable error) {
        [stream close];
        XCTAssertNotNil(db);
        
        NSLog(@"%@", db);
        
        Node* testNode = db.rootGroup.childGroups[0].childRecords[0];
        XCTAssert(testNode);
        XCTAssert([testNode.title isEqualToString:@"Sample Entry"]);
        XCTAssert([testNode.fields.username isEqualToString:@"User Name"]);
        XCTAssert([testNode.fields.password isEqualToString:@"Password"]);

        NSLog(@"%@", testNode.iconId);
        XCTAssert(testNode.iconId.intValue == 0);
        XCTAssert([testNode.customIconUuid.UUIDString isEqualToString:@"E394AE90-219E-C547-8174-976DE6037476"]);

    }];
}

- (void)testCustomIconRecreation {
    NSData *blob = [CommonTesting getDataFromBundleFile:@"custom-icon-4" ofType:@"kdbx"];
    
    id<AbstractDatabaseFormatAdaptor> adaptor = [[Kdbx4Database alloc] init];
    NSInputStream* stream = [NSInputStream inputStreamWithData:blob];
    [stream open];
    [adaptor read:stream
              ckf:[CompositeKeyFactors password:@"a"] completion:^(BOOL userCancelled, StrongboxDatabase * _Nullable b, NSError * _Nullable error) {
         [stream close];
         XCTAssertNotNil(b);
        
        NSLog(@"BEFORE: %@", b);
        
        [adaptor save:b completion:^(BOOL userCancelled, NSData * _Nullable recData, NSError * _Nullable error) {
            NSInputStream* s2 = [NSInputStream inputStreamWithData:recData];
            [s2 open];
            [adaptor read:s2
                      ckf:[CompositeKeyFactors password:@"a"] completion:^(BOOL userCancelled, StrongboxDatabase * _Nullable db, NSError * _Nullable error) {
                [s2 close];
                Node* testNode = db.rootGroup.childGroups[0].childRecords[0];
                XCTAssert(testNode);
                XCTAssert([testNode.title isEqualToString:@"Sample Entry"]);
                XCTAssert([testNode.fields.username isEqualToString:@"User Name"]);
                XCTAssert([testNode.fields.password isEqualToString:@"Password"]);
                
                NSLog(@"%@", testNode.iconId);
                XCTAssert(testNode.iconId.intValue == 0);
                XCTAssert([testNode.customIconUuid.UUIDString isEqualToString:@"E394AE90-219E-C547-8174-976DE6037476"]);
            }];
        }];
    }];
}

- (void)testKdbx4NoCompression {
    NSData *blob = [CommonTesting getDataFromBundleFile:@"db-4-nocompression" ofType:@"kdbx"];
    
    id<AbstractDatabaseFormatAdaptor> adaptor = [[Kdbx4Database alloc] init];
    NSInputStream* stream = [NSInputStream inputStreamWithData:blob];
    [stream open];
    
    [adaptor read:stream
              ckf:[CompositeKeyFactors password:@"a"] completion:^(BOOL userCancelled, StrongboxDatabase * _Nullable db, NSError * _Nullable error) {
        [stream close];
        XCTAssertNotNil(db);
        
        NSLog(@"%@", db);
        
        Node* testNode = db.rootGroup.childGroups[0].childRecords[0];
        XCTAssert(testNode);
        XCTAssert([testNode.title isEqualToString:@"Sample Entry"]);
        XCTAssert([testNode.fields.username isEqualToString:@"User Name"]);
        XCTAssert([testNode.fields.password isEqualToString:@"Password"]);
    }];
}

@end
