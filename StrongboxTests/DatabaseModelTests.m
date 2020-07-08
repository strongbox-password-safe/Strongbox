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
#import "Utils.h"

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
    
    [DatabaseModel fromLegacyData:data
                              ckf:[CompositeKeyFactors password:nil keyFileDigest:digest]
                           config:DatabaseModelConfig.defaults
                       completion:^(BOOL userCancelled, DatabaseModel * _Nonnull model, NSError * _Nonnull error) {
        XCTAssert(model);
        NSLog(@"%@", model);
    }];
}

- (void)testAllTestFilesCanBeOpenedAndSaved {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSURL *directoryURL = [NSURL fileURLWithPath:@"/Users/strongbox/strongbox-test-files"]; // URL pointing to the directory you want to browse
                      
    NSArray *keys = [NSArray arrayWithObject:NSURLIsDirectoryKey];

    NSDirectoryEnumerator *enumerator = [fileManager enumeratorAtURL:directoryURL
                                          includingPropertiesForKeys:keys
                                                             options:0
                                                        errorHandler:^BOOL(NSURL *url, NSError *error) {
            // Handle the error.
            // Return YES if the enumeration should continue after the error.
            return YES;
    }];

    NSSet *validExtensions = [NSSet setWithArray:@[@"kdb", @"kdbx", @"psafe3", @"dat"]];
    
    NSMutableArray<NSURL*>* unopenable = [NSMutableArray array];
    
    for (NSURL *url in enumerator) {
        NSError *error;
        NSNumber *isDirectory = nil;
        if (! [url getResourceValue:&isDirectory forKey:NSURLIsDirectoryKey error:&error]) {
            // handle error
            NSLog(@"error = [%@]", error);
        }
        else if (! [isDirectory boolValue]) {
            if ([validExtensions containsObject:url.pathExtension]) {
                
                NSOutputStream* xmlDumpStream = nil;
                
                if ([url.lastPathComponent isEqualToString:@"favicon-test2-backup.kdbx"]) {
                    xmlDumpStream = [NSOutputStream outputStreamToFileAtPath:[NSString stringWithFormat:@"/Users/strongbox/Desktop/%@.xml", url.lastPathComponent] append:NO];
                    [xmlDumpStream open];
                }
                
                [DatabaseModel fromUrl:url
                                   ckf:[CompositeKeyFactors password:@"a"]
                                config:DatabaseModelConfig.defaults
                         xmlDumpStream:xmlDumpStream
                            completion:^(BOOL userCancelled, DatabaseModel * _Nonnull model, NSError * _Nonnull error) {
                    [xmlDumpStream close];
                    if (error) {
                        NSLog(@"❌ Could not Open [%@]", url);
                        [unopenable addObject:url];
                    }
                    else {
                        NSLog(@"✅ Opened [%@]", url);
                        XCTAssert(model);
                    }
                }];
            }
        }
    }

    NSLog(@"Unopenable for: [%@]", unopenable);
}

- (void)testParticularFileAndDumpXml {
    NSURL* url = [NSURL fileURLWithPath:@"/Users/strongbox/strongbox-test-files/random-tests/keepass/Database-with-empty-attachment.kdbx"];
    NSOutputStream* xmlDumpStream = [NSOutputStream outputStreamToFileAtPath:@"/Users/strongbox/Desktop/unit-test-dump-xml.xml" append:NO];
    [xmlDumpStream open];
    
    [DatabaseModel fromUrl:url
                       ckf:[CompositeKeyFactors password:@"a"]
                    config:DatabaseModelConfig.defaults
             xmlDumpStream:xmlDumpStream
                completion:^(BOOL userCancelled, DatabaseModel * _Nonnull model, NSError * _Nonnull error) {
        [xmlDumpStream close];
        if (error) {
            NSLog(@"❌ Could not Open [%@]", url);
        }
        else {
            NSLog(@"✅ Opened [%@]", url);
            XCTAssert(model);
        }
    }];
}

@end
