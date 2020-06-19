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
    
    [DatabaseModel fromData:data
                        ckf:[CompositeKeyFactors password:nil keyFileDigest:digest]
   useLegacyDeserialization:NO
                 completion:^(BOOL userCancelled, DatabaseModel * _Nonnull model, NSError * _Nonnull error) {
        XCTAssert(model);
        NSLog(@"%@", model);
    }];
}

@end
