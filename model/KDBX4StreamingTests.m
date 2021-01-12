//
//  HmacBlockInputStreamTests.m
//  StrongboxTests
//
//  Created by Strongbox on 08/06/2020.
//  Copyright © 2020 Mark McGuill. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "HmacBlockStream.h"
#import "AesInputStream.h"
#import "GZipInputStream.h"
#import "NSData+Extensions.h"
#import "Kdbx4Database.h"

@interface KDBX4StreamingTests : XCTestCase

@end

@implementation KDBX4StreamingTests

- (void)testHmacBlockStream {
    NSString* b64Key = @"ubUOkhrw8MdxdfPgENNmDDgAPIgdJUI9zqTw0G9woW2OF/5XZy0XEocccln9tpmuS5cUbkTMG7I5tiPDtH3PFQ==";
    NSData* hmacKey = [[NSData alloc] initWithBase64EncodedString:b64Key options:kNilOptions];

    
    NSURL* url = [NSURL fileURLWithPath:@"/Users/strongbox/strongbox-test-files/sample.hmac.blocks"];
    NSInputStream *inputStream = [NSInputStream inputStreamWithURL:url];
    HmacBlockStream *stream = [[HmacBlockStream alloc] initWithStream:inputStream hmacKey:hmacKey];
    XCTAssertNotNil(stream);
    
    [stream open];
    
    const NSUInteger kSize = 512 * 1024 + 17;
    uint8_t buf[kSize];
    
    NSInteger bytesRead = 0;
    NSInteger totalRead = 0;

    while((bytesRead = [stream read:buf maxLength:kSize]) > 0) {
        totalRead += bytesRead;
        
        NSLog(@"%ld => %ld", totalRead, (long)bytesRead);
    }
    
    [stream close];
    
    XCTAssertEqual(totalRead, 242344720);
}

- (void)testHmacStreamAndAes {
    NSString* b64Key = @"ubUOkhrw8MdxdfPgENNmDDgAPIgdJUI9zqTw0G9woW2OF/5XZy0XEocccln9tpmuS5cUbkTMG7I5tiPDtH3PFQ==";
    NSData* hmacKey = [[NSData alloc] initWithBase64EncodedString:b64Key options:kNilOptions];
    
    NSURL* url = [NSURL fileURLWithPath:@"/Users/strongbox/strongbox-test-files/sample.hmac.blocks"];
    NSInputStream *inputStream = [NSInputStream inputStreamWithURL:url];
    HmacBlockStream *innerStream = [[HmacBlockStream alloc] initWithStream:inputStream hmacKey:hmacKey];
    XCTAssertNotNil(innerStream);
    
    NSString* masterb64Key = @"TQxZ44nwA3k9RNJpOl6Zf2LfUw9wcQ5tM6Xm2orCAgo=";
    NSData* masterKey = [[NSData alloc] initWithBase64EncodedString:masterb64Key options:kNilOptions];
    
    NSString* ivb64 = @"2QPSVsuMj8CLL0Xr/y0moQ==";
    NSData* iv = [[NSData alloc] initWithBase64EncodedString:ivb64 options:kNilOptions];
    
    AesInputStream* stream = [[AesInputStream alloc] initWithStream:innerStream key:masterKey iv:iv];
    [stream open];
    
    const NSUInteger kSize = 2*1024*1024;
    uint8_t buf[kSize];
    
    NSInteger bytesRead = 0;
    NSInteger totalRead = 0;

    
    
    while((bytesRead = [stream read:buf maxLength:kSize]) > 0) {
        totalRead += bytesRead;
        
        
    }
    
    [stream close];
    
    NSLog(@"%ld", (long)totalRead);
    
    
    
    XCTAssertEqual(totalRead, 242344710);
}

- (void)testHmacAesAndGzip {
    NSString* b64Key = @"ubUOkhrw8MdxdfPgENNmDDgAPIgdJUI9zqTw0G9woW2OF/5XZy0XEocccln9tpmuS5cUbkTMG7I5tiPDtH3PFQ==";
    NSData* hmacKey = [[NSData alloc] initWithBase64EncodedString:b64Key options:kNilOptions];
    
    NSURL* url = [NSURL fileURLWithPath:@"/Users/strongbox/strongbox-test-files/sample.hmac.blocks"];
    NSInputStream *inputStream = [NSInputStream inputStreamWithURL:url];
    HmacBlockStream *innerStream = [[HmacBlockStream alloc] initWithStream:inputStream hmacKey:hmacKey];
    XCTAssertNotNil(innerStream);
    
    
    
    NSString* masterb64Key = @"TQxZ44nwA3k9RNJpOl6Zf2LfUw9wcQ5tM6Xm2orCAgo=";
    NSData* masterKey = [[NSData alloc] initWithBase64EncodedString:masterb64Key options:kNilOptions];
    NSString* ivb64 = @"2QPSVsuMj8CLL0Xr/y0moQ==";
    NSData* iv = [[NSData alloc] initWithBase64EncodedString:ivb64 options:kNilOptions];
    
    AesInputStream* aesStream = [[AesInputStream alloc] initWithStream:innerStream key:masterKey iv:iv];
    
    
    
    GZipInputStream *stream = [[GZipInputStream alloc] initWithStream:aesStream];
    [stream open];
    
    const NSUInteger kSize = 512 * 1024 + 17;
    uint8_t buf[kSize];
    
    NSInteger bytesRead = 0;
    NSInteger totalRead = 0;

    while((bytesRead = [stream read:buf maxLength:kSize]) > 0) {
        totalRead += bytesRead;
        
        NSLog(@"%ld => %ld", totalRead, (long)bytesRead);
    }
    
    [stream close];
    
    NSLog(@"%ld", (long)totalRead);
    

    
    XCTAssertEqual(totalRead, 276498543);
}

- (void)testLargeAesFile {
    NSData *largeDb = [[NSFileManager defaultManager] contentsAtPath:@"/Users/strongbox/strongbox-test-files/large-test-242-AES-4.kdbx"];
    XCTAssertNotNil(largeDb);
    
    NSURL* url = [NSURL fileURLWithPath:@"/Users/strongbox/strongbox-test-files/large-test-242-AES-4.kdbx"];
    NSInputStream *inputStream = [NSInputStream inputStreamWithURL:url];
    [inputStream open];
    
    [Kdbx4Database read:inputStream
                    ckf:[CompositeKeyFactors password:@"a"]
             completion:^(BOOL userCancelled, DatabaseModel * _Nullable database, NSError * _Nullable error) {
        NSLog(@"%@", database);
        XCTAssertNotNil(database);
        XCTAssertTrue([database.rootNode.children[0].title isEqualToString:@"Database"]);
    }];
}

- (void)testLargeChaCha20File {
    NSInputStream* stream = [NSInputStream inputStreamWithFileAtPath:@"/Users/strongbox/strongbox-test-files/large-test-242-ChaCha20-4.kdbx"];
    [stream open];
    
    [Kdbx4Database read:stream ckf:[CompositeKeyFactors password:@"a"] completion:^(BOOL userCancelled, DatabaseModel * _Nullable db, NSError * _Nullable error) {
        [stream close];
        NSLog(@"%@", db);
        XCTAssertNotNil(db);
        XCTAssertTrue([db.rootNode.children[0].title isEqualToString:@"Database"]);
    }];
}

- (void)testLargeTwoFishFile {
    NSInputStream* stream = [NSInputStream inputStreamWithFileAtPath:@"/Users/strongbox/strongbox-test-files/large-test-242-TwoFish-4.kdbx"];
    [stream open];
    
    [Kdbx4Database read:stream ckf:[CompositeKeyFactors password:@"a"] completion:^(BOOL userCancelled, DatabaseModel * _Nullable db, NSError * _Nullable error) {
        [stream close];
        NSLog(@"%@", db);
        XCTAssertNotNil(db);
        XCTAssertTrue([db.rootNode.children[0].title isEqualToString:@"Database"]);
    }];
}

@end
