//
//  ZlibStreamTests.m
//  StrongboxTests
//
//  Created by Mark on 07/09/2019.
//  Copyright © 2019 Mark McGuill. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "CommonTesting.h"
#import "GZipInputStream.h"

@interface ZlibStreamTests : XCTestCase

@end

@implementation ZlibStreamTests

- (void)testLargeBuffer {
    NSData *largeDb = [[NSFileManager defaultManager] contentsAtPath:@"/Users/strongbox/strongbox-test-files/large-zlib.zlib"];

//    NSData *largeDb = [CommonTesting getDataFromBundleFile:@"large-zlib" ofType:@"zlib"];
    XCTAssertNotNil(largeDb);
    
    GZipInputStream *stream = [[GZipInputStream alloc] initWithData:largeDb];
    
    [stream open];
    
    const NSUInteger kSize = 8192;
    uint8_t buf[kSize];
    
    NSInteger bytesRead = 0;
    NSInteger totalRead = 0;

    while((bytesRead = [stream read:buf maxLength:kSize]) > 0) {
        totalRead += bytesRead;
        //NSLog(@"Read: %ld", (long)bytesRead);
        NSLog(@"%ld => %ld", totalRead, (long)bytesRead);
    }
    
    [stream close];
    
    XCTAssertEqual(totalRead, 73853418);
}

- (void)testLargeBufferStream {
    NSInputStream *fileStream = [NSInputStream inputStreamWithFileAtPath:@"/Users/strongbox/strongbox-test-files/large-zlib.zlib"];
    XCTAssertNotNil(fileStream);
    
    GZipInputStream *stream = [[GZipInputStream alloc] initWithStream:fileStream];
    
    [stream open];
    
    const NSUInteger kSize = 8192;
    uint8_t buf[kSize];
    
    NSInteger bytesRead = 0;
    NSInteger totalRead = 0;

    while((bytesRead = [stream read:buf maxLength:kSize]) > 0) {
        totalRead += bytesRead;
        //NSLog(@"Read: %ld", (long)bytesRead);
        NSLog(@"%ld => %ld", totalRead, (long)bytesRead);
    }
    
    [stream close];
    
    XCTAssertEqual(totalRead, 73853418);
}

@end
