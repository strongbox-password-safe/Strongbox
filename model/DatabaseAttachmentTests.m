//
//  DatabaseAttachmentTests.m
//  StrongboxTests
//
//  Created by Strongbox on 10/06/2020.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "DatabaseAttachment.h"
#import "NSData+Extensions.h"

@interface DatabaseAttachmentTests : XCTestCase

@end

@implementation DatabaseAttachmentTests

- (void)testAddingAllFilesAsAttachmentsStreamedAndUnStreamed {
    NSString* path = @"/Users/strongbox/strongbox-test-files/";

    NSDirectoryEnumerator *enumerator = [NSFileManager.defaultManager enumeratorAtURL:[NSURL URLWithString:path]
                                                           includingPropertiesForKeys:@[NSURLIsDirectoryKey]
                                                                              options:0
                                                                         errorHandler:nil];
    
    for (NSURL *url in enumerator) {
        NSError *error;
        NSNumber *isDirectory = nil;
        if (![url getResourceValue:&isDirectory forKey:NSURLIsDirectoryKey error:&error]) {
            
            NSLog(@"%@", error);
            XCTAssert(NO);
        }
        else if ([isDirectory boolValue]) {
            continue;
        }

        NSString* filename = url.path;
        [self test:filename];
    }
}

- (void)testIndividual {

    [self test:@"/Users/strongbox/strongbox-test-files/Database.kdbx"];
}

- (void)test:(NSString*)filename {
    NSLog(@"Checking File [%@]", filename);
    
    NSError *error;
    NSData* fileData = [NSData dataWithContentsOfFile:filename options:kNilOptions error:&error];
    XCTAssertNotNil(fileData);

    if (fileData == nil || error) {
        NSLog(@"error = [%@]", error);
        return;
    }
            
    NSDictionary<NSFileAttributeKey, id>* attributes = [NSFileManager.defaultManager attributesOfItemAtPath:filename error:&error];
    XCTAssertNotNil(attributes);
    if (error) {
        NSLog(@"error = [%@]", error);
        return;
    }
    
    DatabaseAttachment* dataAttachment = [[DatabaseAttachment alloc] initNonPerformantWithData:fileData compressed:YES protectedInMemory:YES];

    NSUInteger length = attributes.fileSize;
    NSInputStream* stream = [NSInputStream inputStreamWithFileAtPath:filename];
    [stream open];
    DatabaseAttachment* streamAttachment = [[DatabaseAttachment alloc] initWithStream:stream length:length protectedInMemory:YES];
    [stream close];

    NSData* sd = streamAttachment.nonPerformantFullData;
    NSData* dd = dataAttachment.nonPerformantFullData;

    XCTAssertTrue(dataAttachment.estimatedStorageBytes == streamAttachment.estimatedStorageBytes);
    XCTAssertTrue([dataAttachment.digestHash isEqualToString:streamAttachment.digestHash]);
    XCTAssertTrue([dataAttachment.digestHash isEqualToString:dataAttachment.nonPerformantFullData.sha256.hexString]);
    XCTAssertTrue([streamAttachment.digestHash isEqualToString:streamAttachment.nonPerformantFullData.sha256.hexString]);

    NSLog(@"SHA256: [%@] = [%@] = [%@] = [%@]", dataAttachment.digestHash, streamAttachment.digestHash, dd.sha256.hexString, sd.sha256.hexString);

    if (![dataAttachment.digestHash isEqualToString:dd.sha256.hexString]) {
        NSLog(@"Ruh Roh...");
    }

    BOOL eq = [dd isEqualToData:sd];
    XCTAssertTrue(eq);
    
    BOOL origEq = [fileData isEqualToData:dd];
    XCTAssertTrue(origEq);
}

@end
