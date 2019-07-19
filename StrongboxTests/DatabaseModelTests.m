//
//  DatabaseModelTests.m
//  StrongboxTests
//
//  Created by Mark on 06/12/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "CommonTesting.h"
#import "KeyFileParser.h"
#import "DatabaseModel.h"

@interface DatabaseModelTests : XCTestCase

@end

@implementation DatabaseModelTests

- (void)testDatabaseModelXmlKeyFile {
    NSData *key = [CommonTesting getDataFromBundleFile:@"xml-keyfile" ofType:@"key"];
    XCTAssert(key);
    
    NSData* digest = [KeyFileParser getKeyFileDigestFromFileData:key checkForXml:YES];
    XCTAssert(digest);
    
    NSData *data = [CommonTesting getDataFromBundleFile:@"xml-keyfile" ofType:@"kdbx"];
    XCTAssert(data);
    
    NSError *error;
    DatabaseModel* model = [[DatabaseModel alloc] initExisting:data compositeKeyFactors:[CompositeKeyFactors password:nil keyFileDigest:digest] error:&error];
    XCTAssert(model);
    
    NSLog(@"%@", model);
}

@end
