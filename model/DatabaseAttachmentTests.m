//
//  DatabaseAttachmentTests.m
//  StrongboxTests
//
//  Created by Strongbox on 10/06/2020.
//  Copyright © 2020 Mark McGuill. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "DatabaseAttachment.h"
#import "NSData+Extensions.h"

@interface DatabaseAttachmentTests : XCTestCase

@end

@implementation DatabaseAttachmentTests

- (void)testExample {
    NSString* path = @"/Users/strongbox/strongbox-test-files/";
    NSError* error;
    NSArray* files = [NSFileManager.defaultManager contentsOfDirectoryAtPath:path error:&error];
    
    for (NSString* filename in files) {
        //NSString* file = @"/Users/strongbox/strongbox-test-files/Database-Large-Uncompressed.kdbx";
        NSLog(@"Checking File [%@]", filename);
        
        NSString* file = [path stringByAppendingPathComponent:filename];
        NSData* fileData = [NSData dataWithContentsOfFile:file options:kNilOptions error:&error];
        XCTAssertNotNil(fileData);

        if (fileData == nil || error) {
            NSLog(@"error = [%@]", error);
            return;
        }
        
        DatabaseAttachment* dataAttachment = [[DatabaseAttachment alloc] initWithData:fileData compressed:YES protectedInMemory:YES];
        
        NSDictionary<NSFileAttributeKey, id>* attributes = [NSFileManager.defaultManager attributesOfItemAtPath:file error:&error];
        XCTAssertNotNil(attributes);
        if (error) {
            NSLog(@"error = [%@]", error);
            return;
        }
        
        NSUInteger length = attributes.fileSize;
        NSInputStream* stream = [NSInputStream inputStreamWithFileAtPath:file];
        [stream open];
        DatabaseAttachment* streamAttachment = [[DatabaseAttachment alloc] initWithStream:stream length:length protectedInMemory:YES];
        [stream close];
        
        XCTAssertTrue([dataAttachment.digestHash isEqualToString:streamAttachment.digestHash]);
        XCTAssertTrue(dataAttachment.estimatedStorageBytes == streamAttachment.estimatedStorageBytes);
        
        NSLog(@"SHA256: [%@]", dataAttachment.deprecatedData.sha256.hex);
        XCTAssertTrue([dataAttachment.deprecatedData isEqualToData:streamAttachment.deprecatedData]);

        NSLog(@"SHA256: [%@]", dataAttachment.deprecatedData.sha256.hex);
        XCTAssertTrue([dataAttachment.deprecatedData isEqualToData:streamAttachment.deprecatedData]);
    }
}

@end
