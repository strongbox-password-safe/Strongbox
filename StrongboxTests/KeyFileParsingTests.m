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

    NSData* digest = [KeyFileParser getKeyFileDigestFromFileData:blob checkForXml:YES];

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
    
    NSData* digest = [KeyFileParser getKeyFileDigestFromFileData:blob checkForXml:YES];
    
    XCTAssert([[digest base64EncodedStringWithOptions:kNilOptions] isEqualToString:@"FQK8UFYMILsFSw0J2j0TizBuKdZuBbAwdC3QWg8AddY="]);
}

- (void)testLoadHexTextKey {
    NSData *blob = [CommonTesting getDataFromBundleFile:@"sample-hex-text" ofType:@"key"];
    XCTAssert(blob);
    
    NSData* digest = [KeyFileParser getKeyFileDigestFromFileData:blob checkForXml:YES];
    
    XCTAssert([[digest base64EncodedStringWithOptions:kNilOptions] isEqualToString:@"FQK8UFYMILsFSw0J2j0TizBuKdZuBbAwdC3QWg8AddY="]);
}

- (void)testLoadNon64ByteHexFile {
    NSData *blob = [CommonTesting getDataFromBundleFile:@"sample-non-hex-64" ofType:@"key"];
    XCTAssert(blob);
    
    NSData* digest = [KeyFileParser getKeyFileDigestFromFileData:blob checkForXml:YES];
    
    NSLog(@"Digest: [%@]", [digest base64EncodedStringWithOptions:kNilOptions]);
    
    XCTAssert([[digest base64EncodedStringWithOptions:kNilOptions] isEqualToString:@"/yn7c2XAwio/VK3z0fcnIhT1zDRds10rNx8w71QQsxM="]);
}

- (void)testLoadAnyOtherKeyFile {
    NSData *blob = [CommonTesting getDataFromBundleFile:@"ferrari" ofType:@"jpg"];
    XCTAssert(blob);
    
    NSData* digest = [KeyFileParser getKeyFileDigestFromFileData:blob checkForXml:YES];
    
    //NSLog(@"%@", [digest base64EncodedStringWithOptions:kNilOptions]);
    
    XCTAssert([[digest base64EncodedStringWithOptions:kNilOptions] isEqualToString:@"3FYFNJ/4WtG/TrcbtvY24F9nBLMfDkjOKF1ppo9dr30="]);
}

@end
