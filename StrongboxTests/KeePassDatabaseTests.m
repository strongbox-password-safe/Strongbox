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
#import "tomcrypt.h"

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
    NSError* error;
    NSData *safeData = [NSData dataWithContentsOfFile:@"/Users/mark/Google Drive/custom-icon.kdbx" options:kNilOptions error:&error];

    XCTAssertNotNil(safeData);
    
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

- (void)testChaCha20OuterEnc {
    NSData *blob = [CommonTesting getDataFromBundleFile:@"Database-ChCha20-AesKdf" ofType:@"kdbx"];
    
    NSError* error;
    NSString* password = [CommonTesting.testKdbxFilesAndPasswords objectForKey:@"Database-ChCha20-AesKdf"];
    
    KeePassDatabase *db = [[KeePassDatabase alloc] initExistingWithDataAndPassword:blob password:password error:&error];
    
    XCTAssertNotNil(db);

    NSLog(@"================================================ Serializing =======================================================================");

    NSData* data = [db getAsData:&error];
    
    if(error) {
        NSLog(@"%@", error);
    }
    
    XCTAssertNil(error);
    XCTAssertNotNil(data);

    NSLog(@"================================================ Deserializing =======================================================================");

    KeePassDatabase *b = [[KeePassDatabase alloc] initExistingWithDataAndPassword:data password:password error:&error];

    if(error) {
        NSLog(@"%@", error);
    }

    XCTAssertNotNil(b);
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


- (void)testSmallNewDbWithPasswordGetAsDataAndReOpenSafeIsTheSame {
    KeePassDatabase* db = [[KeePassDatabase alloc] initNewWithPassword:@"password"];
    
    XCTAssert([[db.rootGroup.childGroups objectAtIndex:0].title isEqualToString:kDefaultRootGroupName]);
    XCTAssert([db.metadata.generator isEqualToString:@"Strongbox"]);
    XCTAssert(db.metadata.compressionFlags == kGzipCompressionFlag);
    
    Node* keePassRoot = [db.rootGroup.childGroups objectAtIndex:0];
    
    DatabaseAttachment *attachment1 = [[DatabaseAttachment alloc] init];
    attachment1.compressed = NO;
    NSData* data1 = [@"This is attachment 1 UTF data" dataUsingEncoding:NSUTF8StringEncoding];
    attachment1.data = data1;
    
    DatabaseAttachment *attachment2 = [[DatabaseAttachment alloc] init];
    attachment2.compressed = NO;
    NSData *data2 = [@"This is attachment 2 UTF data" dataUsingEncoding:NSUTF8StringEncoding];
    attachment2.data = data2;
    
    [db.attachments addObjectsFromArray:@[attachment1, attachment2]];
    
    //
    
    NodeFields *fields = [[NodeFields alloc] initWithUsername:@"username" url:@"url" password:@"ladder" notes:@"notes" email:@"email"];
    
    //
    
    NodeFileAttachment *nodeAttachment1 = [[NodeFileAttachment alloc] init];
    nodeAttachment1.index = 0;
    nodeAttachment1.filename = @"attachment1.txt";
    
    NodeFileAttachment *nodeAttachment2 = [[NodeFileAttachment alloc] init];
    nodeAttachment2.index = 1;
    nodeAttachment2.filename = @"attachment2.txt";
    
    [fields.attachments addObjectsFromArray:@[nodeAttachment1, nodeAttachment2]];
    
    //
    
    Node* record = [[Node alloc] initAsRecord:@"Title" parent:keePassRoot fields:fields uuid:nil];
    [keePassRoot addChild:record];
    
    //NSLog(@"BEFORE: %@", db);
    
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
    
    //NSLog(@"AFTER: %@", b);
    
    XCTAssert([[b.rootGroup.childGroups objectAtIndex:0].title isEqualToString:kDefaultRootGroupName]);
    XCTAssert([b.metadata.generator isEqualToString:@"Strongbox"]);
    XCTAssert(b.metadata.compressionFlags == kGzipCompressionFlag);
    
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
    XCTAssert([b.attachments[0].data isEqualToData:data1]);
    XCTAssert([b.attachments[1].data isEqualToData:data2]);
}

- (void)testKdbxTwoFishOuterAesKdf {
    NSData *blob = [CommonTesting getDataFromBundleFile:@"TwoFish-with-AesKdf" ofType:@"kdbx"];
    
    NSError* error;
    KeePassDatabase *db = [[KeePassDatabase alloc] initExistingWithDataAndPassword:blob password:@"a" error:&error];
    
    XCTAssertNotNil(db);
    
    NSLog(@"%@", db);
    
    Node* testNode = db.rootGroup.childGroups[0].childRecords[0];
    XCTAssert(testNode);
    XCTAssert([testNode.title isEqualToString:@"New Entry"]);
    XCTAssert([testNode.fields.username isEqualToString:@"mmyf"]);
    XCTAssert([testNode.fields.password isEqualToString:@"bbgh"]);
}

- (void)testKdbxTwoFishOuterAesKdfReadAndWrite {
    NSData *blob = [CommonTesting getDataFromBundleFile:@"TwoFish-with-AesKdf" ofType:@"kdbx"];
    
    NSError* error;
    KeePassDatabase *db = [[KeePassDatabase alloc] initExistingWithDataAndPassword:blob password:@"a" error:&error];
    
    XCTAssertNotNil(db);
    
    //NSLog(@"BEFORE: %@", db);

    Node* testNode = db.rootGroup.childGroups[0].childRecords[0];
    
    XCTAssert(testNode);
    XCTAssert([testNode.title isEqualToString:@"New Entry"]);
    XCTAssert([testNode.fields.username isEqualToString:@"mmyf"]);
    XCTAssert([testNode.fields.password isEqualToString:@"bbgh"]);

    testNode.title = @"New Entry13333576hg-6sqIXJVO;Q";
    
    NSData* d = [db getAsData:&error];

    KeePassDatabase *b = [[KeePassDatabase alloc] initExistingWithDataAndPassword:d password:@"a" error:&error];
    
    testNode = b.rootGroup.childGroups[0].childRecords[0];
    XCTAssert(testNode);
    XCTAssert([testNode.title isEqualToString:@"New Entry13333576hg-6sqIXJVO;Q"]);
    XCTAssert([testNode.fields.username isEqualToString:@"mmyf"]);
    XCTAssert([testNode.fields.password isEqualToString:@"bbgh"]);
}

- (void)testTwoFishEncDec {
    int err;
    symmetric_key cbckey;
    
    NSData* key = [[NSData alloc] initWithBase64EncodedString:@"awDGtfRfVhyG+Qo56WD7Qq7bSLMRl38zUoy5NM9Hv6Q=" options:kNilOptions];
    int kBlockSize = 16;
    
    if ((err = twofish_setup(key.bytes, kBlockSize, 0, &cbckey)) != CRYPT_OK) {
        NSLog(@"Invalid Key");
        return;
    }
    
    //////////////////////////
    
    //NSData* orig = [@"0123456789ABCDEF" dataUsingEncoding:NSUTF8StringEncoding];
    
    NSData* orig = [[NSData alloc] initWithBase64EncodedString:@"1jGTF1Szwo/FmwOpQu8L/g==" options:kNilOptions];
    
    NSLog(@"BEFORE %@", [orig base64EncodedStringWithOptions:kNilOptions]);
    
    uint8_t ct[kBlockSize];
    twofish_ecb_encrypt(orig.bytes, ct, &cbckey);
    
    
    uint8_t ecbPt[kBlockSize];
    twofish_ecb_decrypt(ct, ecbPt, &cbckey);

    NSData *pt = [[NSData alloc] initWithBytes:ecbPt length:kBlockSize];
    NSLog(@"AFTER %@", [pt base64EncodedStringWithOptions:kNilOptions]);
}

- (void)testRwBinariesFileCompress {
    NSData *blob = [CommonTesting getDataFromBundleFile:@"Database" ofType:@"kdbx"];
    NSError* error;
    KeePassDatabase *db = [[KeePassDatabase alloc] initExistingWithDataAndPassword:blob password:@"a" error:&error];
    
    NSData* b = [db getAsData:&error];
    
    KeePassDatabase *a = [[KeePassDatabase alloc] initExistingWithDataAndPassword:b password:@"a" error:&error];
    
    XCTAssertNotNil(a);
}

@end
