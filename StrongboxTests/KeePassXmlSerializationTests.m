//
//  StrongboxTests.m
//  StrongboxTests
//
//  Created by Mark on 16/10/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "KeePassDatabase.h"
#import "XmlStrongboxNodeModelAdaptor.h"
#import "KdbxSerialization.h"
#import "CommonTesting.h"

@interface KeePassXmlSerializationTests : XCTestCase

@end

@implementation KeePassXmlSerializationTests

- (void)setUp {
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
}

- (void)testDeserializeGzippedFile {
    NSBundle *bundle = [NSBundle bundleForClass:[self class]];
    NSString *path = [bundle pathForResource:@"generic" ofType:@"kdbx"];
    NSData* safeData = [NSData dataWithContentsOfFile:path];
    
    NSError* error;
    //KeePassDatabase *db = [[KeePassDatabase alloc] initExistingWithDataAndPassword:safeData password:@"a" error:&error];

    SerializationData* data = [KdbxSerialization deserialize:safeData password:@"a" keyFileDigest:nil ppError:&error];
    
    if(!data) {
        NSLog(@"%@", error);
    }
    
    XCTAssert(data != nil);

    NSLog(@"%@", data);
    //NSLog(@"%@", data.xml);
    XCTAssert([data.xml hasPrefix:@"<?xml"]);
}

- (void)testDeserializeNonGzippedFile {
    NSBundle *bundle = [NSBundle bundleForClass:[self class]];
    NSString *path = [bundle pathForResource:@"generic-non-gzipped" ofType:@"kdbx"];
    NSData* safeData = [NSData dataWithContentsOfFile:path];
    
    NSError* error;
    //KeePassDatabase *db = [[KeePassDatabase alloc] initExistingWithDataAndPassword:safeData password:@"a" error:&error];
    
    SerializationData* data = [KdbxSerialization deserialize:safeData password:@"a" keyFileDigest:nil ppError:&error];
    
    if(!data) {
        NSLog(@"%@", error);
    }
    
    XCTAssert(data != nil);
    
    NSLog(@"%@", data);
    //NSLog(@"%@", data.xml);
    XCTAssert([data.xml hasPrefix:@"<?xml"]);
}
//
//- (void)testDeserializeDesktopFileToXml {
//    NSData *safeData = [[NSFileManager defaultManager] contentsAtPath:@"/Users/mark/Desktop/Database.kdbx"];
//
//    NSError* error;
//    //KeePassDatabase *db = [[KeePassDatabase alloc] initExistingWithDataAndPassword:safeData password:@"a" error:&error];
//
//    SerializationData* data = [KdbxSerialization deserialize:safeData password:@"a" ppError:&error];
//
//    if(!data) {
//        NSLog(@"%@", error);
//    }
//
//    XCTAssert(data != nil);
//
//    NSLog(@"%@", data);
//    NSLog(@"%@", data.xml);
//    XCTAssert([data.xml hasPrefix:@"<?xml"]);
//
//    [[NSFileManager defaultManager] createFileAtPath:@"/Users/mark/Desktop/Database.xml" contents:[data.xml dataUsingEncoding:NSUTF8StringEncoding] attributes:nil];
//}

- (void)testDeserializeGoogleDriveFileToXml {
    NSData *safeData = [[NSFileManager defaultManager] contentsAtPath:@"/Users/mark/Google Drive/strongbox/keepass/Database.kdbx"];
    
    NSError* error;
    //KeePassDatabase *db = [[KeePassDatabase alloc] initExistingWithDataAndPassword:safeData password:@"a" error:&error];
    
    SerializationData* data = [KdbxSerialization deserialize:safeData password:@"a" keyFileDigest:nil ppError:&error];
    
    if(!data) {
        NSLog(@"%@", error);
    }
    
    XCTAssert(data != nil);
    
    NSLog(@"%@", data);
    NSLog(@"%@", data.xml);
    XCTAssert([data.xml hasPrefix:@"<?xml"]);
    
    [[NSFileManager defaultManager] createFileAtPath:@"/Users/mark/Desktop/Database.xml" contents:[data.xml dataUsingEncoding:NSUTF8StringEncoding] attributes:nil];
}

- (void)testDeserializeFileWithBinariesAndCustomFields {
    NSBundle *bundle = [NSBundle bundleForClass:[self class]];
    NSString *path = [bundle pathForResource:@"Database" ofType:@"kdbx"];
    NSData* safeData = [NSData dataWithContentsOfFile:path];
    
    NSError* error;
    //KeePassDatabase *db = [[KeePassDatabase alloc] initExistingWithDataAndPassword:safeData password:@"a" error:&error];
    
    SerializationData* data = [KdbxSerialization deserialize:safeData password:@"a" keyFileDigest:nil ppError:&error];
    
    if(!data) {
        NSLog(@"%@", error);
    }
    
    XCTAssert(data != nil);
    
    NSLog(@"%@", data);
    //NSLog(@"%@", data.xml);
    XCTAssert([data.xml hasPrefix:@"<?xml"]);
    
    NSLog(@"%@", data.xml);
}

@end
