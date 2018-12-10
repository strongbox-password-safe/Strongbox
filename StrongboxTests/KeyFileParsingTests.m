//
//  KeyFileParsingTests.m
//  StrongboxTests
//
//  Created by Mark on 04/12/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "CommonTesting.h"
#import "KeyFileParser.h"
#import "DatabaseModel.h"

@interface KeyFileParsingTests : XCTestCase

@end

@implementation KeyFileParsingTests

- (void)testXmlKeyFile {
    NSData *blob = [CommonTesting getDataFromBundleFile:@"sample-xml" ofType:@"key"];
    XCTAssert(blob);

    NSData* digest = [KeyFileParser getKeyFileDigestFromFileData:blob];

//    NSMutableString *str = [[NSMutableString alloc] init];
//    uint8_t *current = (uint8_t*)digest.bytes;
//    
//    for(int i=0;i<32;i++, current++) {
//        [str appendFormat:@"%0.2x", *current];
//    }
//
//    NSLog(@"%@", str);
    
    //[digest writeToFile:@"/Users/mark/Desktop/sample-32-binary" atomically:YES];
    
    NSLog(@"%@", [digest base64EncodedStringWithOptions:kNilOptions]);
    
    XCTAssert([[digest base64EncodedStringWithOptions:kNilOptions] isEqualToString:@"qoqpuiBtJAbJZI8XL3DxGqQkxEo6HZbxnhCStAZIYsE="]);
}

- (void)testLoad32ByteBinaryKey {
    NSData *blob = [CommonTesting getDataFromBundleFile:@"sample-32-binary" ofType:@"key"];
    XCTAssert(blob);
    
    NSData* digest = [KeyFileParser getKeyFileDigestFromFileData:blob];
    
    XCTAssert([[digest base64EncodedStringWithOptions:kNilOptions] isEqualToString:@"FQK8UFYMILsFSw0J2j0TizBuKdZuBbAwdC3QWg8AddY="]);
}

- (void)testLoadHexTextKey {
    NSData *blob = [CommonTesting getDataFromBundleFile:@"sample-hex-text" ofType:@"key"];
    XCTAssert(blob);
    
    NSData* digest = [KeyFileParser getKeyFileDigestFromFileData:blob];
    
    XCTAssert([[digest base64EncodedStringWithOptions:kNilOptions] isEqualToString:@"FQK8UFYMILsFSw0J2j0TizBuKdZuBbAwdC3QWg8AddY="]);
}

- (void)testLoadAnyOtherKeyFile {
    NSData *blob = [CommonTesting getDataFromBundleFile:@"ferrari" ofType:@"jpg"];
    XCTAssert(blob);
    
    NSData* digest = [KeyFileParser getKeyFileDigestFromFileData:blob];
    
    //NSLog(@"%@", [digest base64EncodedStringWithOptions:kNilOptions]);
    
    XCTAssert([[digest base64EncodedStringWithOptions:kNilOptions] isEqualToString:@"3FYFNJ/4WtG/TrcbtvY24F9nBLMfDkjOKF1ppo9dr30="]);
}

@end
