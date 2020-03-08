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
#import "Kdbx4Database.h"

@interface KeePassDatabaseTests : XCTestCase

@end

@implementation KeePassDatabaseTests

- (void)testInitExistingWithAllKdbxTestFiles {
    for (NSString* file in CommonTesting.testKdbxFilesAndPasswords) {
        NSLog(@"=============================================================================================================");
        NSLog(@"===================================== %@ ===============================================", file);

        NSData *blob = [CommonTesting getDataFromBundleFile:file ofType:@"kdbx"];
        
        NSString* password = [CommonTesting.testKdbxFilesAndPasswords objectForKey:file];
        
        id<AbstractDatabaseFormatAdaptor> adaptor = [[KeePassDatabase alloc] init];
        
        [adaptor open:blob ckf:[CompositeKeyFactors password:password] completion:^(BOOL userCancelled, StrongboxDatabase * _Nullable database, NSError * _Nullable error) {
            XCTAssertNotNil(database);

            NSLog(@"%@", database);
            NSLog(@"=============================================================================================================");
        }];
    }
}

- (void)testInitExistingWithATestFile {
    NSData *blob = [CommonTesting getDataFromBundleFile:@"a" ofType:@"kdbx"];
    
    id<AbstractDatabaseFormatAdaptor> adaptor = [[KeePassDatabase alloc] init];
    
    [adaptor open:blob
              ckf:[CompositeKeyFactors password:@"a"]
       completion:^(BOOL userCancelled, StrongboxDatabase * _Nullable db, NSError * _Nullable error) {
        XCTAssertNotNil(db);
        
        NSLog(@"%@", db);

        XCTAssert(db.rootGroup.childGroups.count == 1);
        XCTAssert([[db.rootGroup.childGroups objectAtIndex:0].title isEqualToString:@"General"]);
        XCTAssert([[[db.rootGroup.childGroups objectAtIndex:0].childGroups objectAtIndex:5].title isEqualToString:@"New Group"]);
        XCTAssert([[[[db.rootGroup.childGroups objectAtIndex:0].childGroups objectAtIndex:5].childRecords objectAtIndex:0].fields.password isEqualToString:@"ladder"]);
    }];
}

- (void)testInitExistingWithCustomAndBinariesFile {
    NSData *blob = [CommonTesting getDataFromBundleFile:@"Database" ofType:@"kdbx"];
    
    id<AbstractDatabaseFormatAdaptor> adaptor = [[KeePassDatabase alloc] init];
    
    [adaptor open:blob ckf:[CompositeKeyFactors password:@"a"] completion:^(BOOL userCancelled, StrongboxDatabase * _Nullable database, NSError * _Nullable error) {
        XCTAssertNotNil(database);
    }];
}

- (void)testInitExistingWithGoogleDriveSafe {
    NSError* error;
    NSData *safeData = [NSData dataWithContentsOfFile:@"/Users/mark/Google Drive/strongbox/keepass/kp2-twofish-with-aes-kdf.kdbx" options:kNilOptions error:&error];

    XCTAssertNotNil(safeData);
    
    id<AbstractDatabaseFormatAdaptor> adaptor = [[KeePassDatabase alloc] init];
    
    [adaptor open:safeData ckf:[CompositeKeyFactors password:@"a"] completion:^(BOOL userCancelled, StrongboxDatabase * _Nullable database, NSError * _Nullable error) {
        NSLog(@"%@", database);
        XCTAssertNotNil(database);
    }];
}

- (void)testInitNew {
    id<AbstractDatabaseFormatAdaptor> adaptor = [[KeePassDatabase alloc] init];
    StrongboxDatabase* db = [adaptor create:[CompositeKeyFactors password:@"password"]];
    
    NSLog(@"%@", db);
    
    KeePassDatabaseMetadata *metadata = db.metadata;
    XCTAssert([[db.rootGroup.childGroups objectAtIndex:0].title isEqualToString:kDefaultRootGroupName]);
    XCTAssert([metadata.generator isEqualToString:@"Strongbox"]);
    XCTAssert(metadata.compressionFlags == kGzipCompressionFlag);
}

- (void)testEmptyDbGetAsDataAndReOpenSafeIsTheSame {
    id<AbstractDatabaseFormatAdaptor> adaptor = [[KeePassDatabase alloc] init];
    StrongboxDatabase* db = [adaptor create:[CompositeKeyFactors password:@"password"]];
    
    NSLog(@"%@", db);
    
    KeePassDatabaseMetadata *metadata = db.metadata;
    XCTAssert([[db.rootGroup.childGroups objectAtIndex:0].title isEqualToString:kDefaultRootGroupName]);
    XCTAssert([metadata.generator isEqualToString:@"Strongbox"]);
    XCTAssert(metadata.compressionFlags == kGzipCompressionFlag);

    [adaptor save:db completion:^(BOOL userCancelled, NSData * _Nullable data, NSError * _Nullable error) {
        if(error) {
           NSLog(@"%@", error);
        }

        XCTAssertNil(error);
        XCTAssertNotNil(data);

        [adaptor open:data
                  ckf:[CompositeKeyFactors password:@"password"]
           completion:^(BOOL userCancelled, StrongboxDatabase * _Nullable database, NSError * _Nullable error) {
            if(error) {
               NSLog(@"%@", error);
            }

            XCTAssertNotNil(database);

            NSLog(@"%@", database);

            KeePassDatabaseMetadata *metadata = database.metadata;
            XCTAssert([[database.rootGroup.childGroups objectAtIndex:0].title isEqualToString:kDefaultRootGroupName]);
            XCTAssert([metadata.generator isEqualToString:@"Strongbox"]);
            XCTAssert(metadata.compressionFlags == kGzipCompressionFlag);
        }];
    }];
}

- (void)testChaCha20OuterEnc {
    NSData *blob = [CommonTesting getDataFromBundleFile:@"Database-ChCha20-AesKdf" ofType:@"kdbx"];
    
    NSString* password = [CommonTesting.testKdbxFilesAndPasswords objectForKey:@"Database-ChCha20-AesKdf"];
    
    id<AbstractDatabaseFormatAdaptor> adaptor = [[KeePassDatabase alloc] init];
    
    [adaptor open:blob
              ckf:[CompositeKeyFactors password:password]
       completion:^(BOOL userCancelled, StrongboxDatabase * _Nullable db, NSError * _Nullable error) {
        XCTAssertNotNil(db);

        NSLog(@"================================================ Serializing =======================================================================");

        [adaptor save:db completion:^(BOOL userCancelled, NSData * _Nullable data, NSError * _Nullable error) {
            if(error) {
                NSLog(@"%@", error);
            }
            
            XCTAssertNil(error);
            XCTAssertNotNil(data);

            NSLog(@"================================================ Deserializing =======================================================================");

            [adaptor open:data ckf:[CompositeKeyFactors password:password] completion:^(BOOL userCancelled, StrongboxDatabase * _Nullable b, NSError * _Nullable error) {
                if(error) {
                    NSLog(@"%@", error);
                }

                XCTAssertNotNil(b);
            }];
        }];
    }];
}

- (void)testOpenSaveOpenWithAllKdbxTestFiles {
    for (NSString* file in CommonTesting.testKdbxFilesAndPasswords) {
        NSLog(@"=============================================================================================================");
        NSLog(@"===================================== %@ ===============================================", file);
        
        NSData *blob = [CommonTesting getDataFromBundleFile:file ofType:@"kdbx"];
        
        NSString* password = [CommonTesting.testKdbxFilesAndPasswords objectForKey:file];
        
        id<AbstractDatabaseFormatAdaptor> adaptor = [[KeePassDatabase alloc] init];
        
        [adaptor open:blob ckf:[CompositeKeyFactors password:password] completion:^(BOOL userCancelled, StrongboxDatabase * _Nullable db, NSError * _Nullable error) {
            XCTAssertNotNil(db);
            
            //NSLog(@"%@", db);
        NSLog(@"=============================================================================================================");
        
            [adaptor save:db completion:^(BOOL userCancelled, NSData * _Nullable data, NSError * _Nullable error) {
                if(error) {
                    NSLog(@"%@", error);
                }
                
                XCTAssertNil(error);
                XCTAssertNotNil(data);
                
                [adaptor open:data ckf:[CompositeKeyFactors password:password] completion:^(BOOL userCancelled, StrongboxDatabase * _Nullable b, NSError * _Nullable error) {
                    if(error) {
                        NSLog(@"%@", error);
                    }
                    
                    XCTAssertNotNil(b);
                }];
            }];
        }];
    }
}

- (void)testDbModifyCreateLarge {
    id<AbstractDatabaseFormatAdaptor> adaptor = [[KeePassDatabase alloc] init];
    StrongboxDatabase* db = [adaptor create:[CompositeKeyFactors password:@"password"]];
    
    NSLog(@"%@", db);
    
    for(int i=0;i<1000;i++) {
        NodeFields *fields = [[NodeFields alloc] init];
        Node *childNode = [[Node alloc] initAsRecord:[NSString stringWithFormat:@"Title %d", i] parent:[db.rootGroup.childGroups objectAtIndex:0] fields:fields uuid:nil];
        [[db.rootGroup.childGroups objectAtIndex:0] addChild:childNode keePassGroupTitleRules:YES];
    }
    
    [adaptor save:db completion:^(BOOL userCancelled, NSData * _Nullable data, NSError * _Nullable error) {
        if(error) {
            NSLog(@"%@", error);
        }

        XCTAssertNil(error);
        XCTAssertNotNil(data);

        //    [data writeToFile:@"/Users/mark/Desktop/large.kdbx" options:kNilOptions error:&error];

        NSLog(@"%@", error);
    }];
}

- (void)testDbModifyWithEscapeCharacterGetAsDataAndReOpenSafeIsTheSame {
    id<AbstractDatabaseFormatAdaptor> adaptor = [[KeePassDatabase alloc] init];
    StrongboxDatabase* db = [adaptor create:[CompositeKeyFactors password:@"password"]];
    
    NSLog(@"%@", db);
    
    XCTAssert([[db.rootGroup.childGroups objectAtIndex:0].title isEqualToString:kDefaultRootGroupName]);
    
    KeePassDatabaseMetadata* metadata = db.metadata;
    XCTAssert([metadata.generator isEqualToString:@"Strongbox"]);
    XCTAssert(metadata.compressionFlags == kGzipCompressionFlag);
    
    NodeFields *fields = [[NodeFields alloc] init];
    NSString* const escape = @"Title &<>'\\ &amp; &lt; Done-<site url=\"http://example.com/?a=b&amp;b=c\"; />";
    
    Node *childNode = [[Node alloc] initAsRecord:escape
                                          parent:[db.rootGroup.childGroups objectAtIndex:0]
                                          fields:fields
                                            uuid:nil];
    
    [[db.rootGroup.childGroups objectAtIndex:0] addChild:childNode keePassGroupTitleRules:YES];
    
    [adaptor save:db completion:^(BOOL userCancelled, NSData * _Nullable data, NSError * _Nullable error) {
        if(error) {
            NSLog(@"%@", error);
        }
        
        XCTAssertNil(error);
        XCTAssertNotNil(data);

        [adaptor open:data ckf:[CompositeKeyFactors password:@"password"]
           completion:^(BOOL userCancelled, StrongboxDatabase * _Nullable b, NSError * _Nullable error) {
            if(error) {
                NSLog(@"%@", error);
            }
            
            XCTAssertNotNil(b);
            
            NSLog(@"%@", b);

            KeePassDatabaseMetadata* metadata = b.metadata;
            XCTAssert([[b.rootGroup.childGroups objectAtIndex:0].title isEqualToString:kDefaultRootGroupName]);
            XCTAssert([metadata.generator isEqualToString:@"Strongbox"]);
            XCTAssert(metadata.compressionFlags == kGzipCompressionFlag);

            XCTAssertEqualObjects([[[b.rootGroup.childGroups objectAtIndex:0] childRecords] objectAtIndex:0].title, escape);
        }];
    }];
}

- (void)testSmallNewDbWithPasswordGetAsDataAndReOpenSafeIsTheSame {
    id<AbstractDatabaseFormatAdaptor> adaptor = [[KeePassDatabase alloc] init];
    StrongboxDatabase* db = [adaptor create:[CompositeKeyFactors password:@"password"]];
    
    KeePassDatabaseMetadata* metadata = db.metadata;
    XCTAssert([[db.rootGroup.childGroups objectAtIndex:0].title isEqualToString:kDefaultRootGroupName]);
    XCTAssert([metadata.generator isEqualToString:@"Strongbox"]);
    XCTAssert(metadata.compressionFlags == kGzipCompressionFlag);
    
    Node* keePassRoot = [db.rootGroup.childGroups objectAtIndex:0];
    
    NSData* data1 = [@"This is attachment 1 UTF data" dataUsingEncoding:NSUTF8StringEncoding];
    NSData *data2 = [@"This is attachment 2 UTF data" dataUsingEncoding:NSUTF8StringEncoding];
    
    NodeFields *fields = [[NodeFields alloc] initWithUsername:@"username" url:@"url" password:@"ladder" notes:@"notes" email:@"email"];
    
    Node* record = [[Node alloc] initAsRecord:@"Title" parent:keePassRoot fields:fields uuid:nil];
    [keePassRoot addChild:record keePassGroupTitleRules:YES];
    
    [db addNodeAttachment:record attachment:[[UiAttachment alloc] initWithFilename:@"attachment1.txt" data:data1]];
    [db addNodeAttachment:record attachment:[[UiAttachment alloc] initWithFilename:@"attachment2.txt" data:data2]];
     
     //NSLog(@"BEFORE: %@", db);
    
    [adaptor save:db completion:^(BOOL userCancelled, NSData * _Nullable data, NSError * _Nullable error) {
        if(error) {
            NSLog(@"%@", error);
        }
        
        XCTAssertNil(error);
        XCTAssertNotNil(data);
        
        [adaptor open:data ckf:[CompositeKeyFactors password:@"password"] completion:^(BOOL userCancelled, StrongboxDatabase * _Nullable b, NSError * _Nullable error) {
            if(error) {
                NSLog(@"%@", error);
            }
            
            XCTAssertNotNil(b);
            
            //NSLog(@"AFTER: %@", b);
            
            XCTAssert([[b.rootGroup.childGroups objectAtIndex:0].title isEqualToString:kDefaultRootGroupName]);
            
            KeePassDatabaseMetadata* metadata = b.metadata;
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
            XCTAssert([b.attachments[0].data isEqualToData:data1]);
            XCTAssert([b.attachments[1].data isEqualToData:data2]);

        }];
    }];
}

- (void)testKdbxTwoFishOuterAesKdf {
    NSData *blob = [CommonTesting getDataFromBundleFile:@"TwoFish-with-AesKdf" ofType:@"kdbx"];
    
    id<AbstractDatabaseFormatAdaptor> adaptor = [[KeePassDatabase alloc] init];
    
    [adaptor open:blob ckf:[CompositeKeyFactors password:@"a"] completion:^(BOOL userCancelled, StrongboxDatabase * _Nullable db, NSError * _Nullable error) {
        XCTAssertNotNil(db);
        
        NSLog(@"%@", db);
        
        Node* testNode = db.rootGroup.childGroups[0].childRecords[0];
        XCTAssert(testNode);
        XCTAssert([testNode.title isEqualToString:@"New Entry"]);
        XCTAssert([testNode.fields.username isEqualToString:@"mmyf"]);
        XCTAssert([testNode.fields.password isEqualToString:@"bbgh"]);
    }];
}

- (void)testKdbxTwoFishOuterAesKdfReadAndWrite {
    NSData *blob = [CommonTesting getDataFromBundleFile:@"TwoFish-with-AesKdf" ofType:@"kdbx"];
    id<AbstractDatabaseFormatAdaptor> adaptor = [[KeePassDatabase alloc] init];
    
    [adaptor open:blob ckf:[CompositeKeyFactors password:@"a"]
       completion:^(BOOL userCancelled, StrongboxDatabase * _Nullable db, NSError * _Nullable error) {
        XCTAssertNotNil(db);
        
        //NSLog(@"BEFORE: %@", db);

        Node* testNode = db.rootGroup.childGroups[0].childRecords[0];
        
        XCTAssert(testNode);
        XCTAssert([testNode.title isEqualToString:@"New Entry"]);
        XCTAssert([testNode.fields.username isEqualToString:@"mmyf"]);
        XCTAssert([testNode.fields.password isEqualToString:@"bbgh"]);

        [testNode setTitle:@"New Entry13333576hg-6sqIXJVO;Q" keePassGroupTitleRules:YES];
        
        [adaptor save:db completion:^(BOOL userCancelled, NSData * _Nullable d, NSError * _Nullable error) {
            [adaptor open:d ckf:[CompositeKeyFactors password:@"a"] completion:^(BOOL userCancelled, StrongboxDatabase * _Nullable b, NSError * _Nullable error) {
                Node* testNode = b.rootGroup.childGroups[0].childRecords[0];
                XCTAssert(testNode);
                XCTAssert([testNode.title isEqualToString:@"New Entry13333576hg-6sqIXJVO;Q"]);
                XCTAssert([testNode.fields.username isEqualToString:@"mmyf"]);
                XCTAssert([testNode.fields.password isEqualToString:@"bbgh"]);
            }];
        }];
    }];
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

    id<AbstractDatabaseFormatAdaptor> adaptor = [[KeePassDatabase alloc] init];
    
    [adaptor open:blob
              ckf:[CompositeKeyFactors password:@"a"]
       completion:^(BOOL userCancelled, StrongboxDatabase * _Nullable database, NSError * _Nullable error) {
        [adaptor save:database completion:^(BOOL userCancelled, NSData * _Nullable data, NSError * _Nullable error) {
            [adaptor open:data ckf:[CompositeKeyFactors password:@"a"] completion:^(BOOL userCancelled, StrongboxDatabase * _Nullable a, NSError * _Nullable error) {
                XCTAssertNotNil(a);
            }];
        }];
    }];
}

- (void)testDbMaxHistorySettings {
    id<AbstractDatabaseFormatAdaptor> adaptor = [[KeePassDatabase alloc] init];
    StrongboxDatabase* db = [adaptor create:[CompositeKeyFactors password:@"password"]];
    
    NSLog(@"%@", db);
    
    XCTAssert([[db.rootGroup.childGroups objectAtIndex:0].title isEqualToString:kDefaultRootGroupName]);
    
    KeePassDatabaseMetadata* metadata = db.metadata;
    XCTAssert(metadata.historyMaxItems.intValue == 10);
    
    metadata.historyMaxItems = @(2412);
    
    //

    [adaptor save:db completion:^(BOOL userCancelled, NSData * _Nullable data, NSError * _Nullable error) {
        if(error) {
            NSLog(@"%@", error);
        }
        
        XCTAssertNil(error);
        XCTAssertNotNil(data);
        
        [adaptor open:data ckf:[CompositeKeyFactors password:@"password"] completion:^(BOOL userCancelled, StrongboxDatabase * _Nullable b, NSError * _Nullable error) {
            if(error) {
                NSLog(@"%@", error);
            }
            
            XCTAssertNotNil(b);
            
            NSLog(@"%@", b);

            
            KeePassDatabaseMetadata* metadata = b.metadata;
            XCTAssert(metadata.historyMaxItems.intValue == 2412);
        }];
    }];
}

- (void)testDbMaxHistorySettings4 {
    id<AbstractDatabaseFormatAdaptor> adaptor = [[Kdbx4Database alloc] init];
    StrongboxDatabase* db = [adaptor create:[CompositeKeyFactors password:@"password"]];
    
    NSLog(@"%@", db);
    
    XCTAssert([[db.rootGroup.childGroups objectAtIndex:0].title isEqualToString:kDefaultRootGroupName]);
    
    KeePassDatabaseMetadata* metadata = db.metadata;
    XCTAssert(metadata.historyMaxItems.intValue == 10);
    
    metadata.historyMaxItems = @(2412);
    
    //
    
    
    [adaptor save:db completion:^(BOOL userCancelled, NSData * _Nullable data, NSError * _Nullable error) {
        if(error) {
            NSLog(@"%@", error);
        }
        
        XCTAssertNil(error);
        XCTAssertNotNil(data);
        
        [adaptor open:data ckf:[CompositeKeyFactors password:@"password"] completion:^(BOOL userCancelled, StrongboxDatabase * _Nullable b, NSError * _Nullable error) {
            if(error) {
                NSLog(@"%@", error);
            }
            
            XCTAssertNotNil(b);
            
            NSLog(@"%@", b);
            
            KeePassDatabaseMetadata* metadata = b.metadata;
            XCTAssert(metadata.historyMaxItems.intValue == 2412);
        }];
    }];
}

@end
