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
    
    [DatabaseModel fromData:data
                        ckf:[CompositeKeyFactors password:nil keyFileDigest:digest]
   useLegacyDeserialization:NO
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
                NSData* data = [NSData dataWithContentsOfURL:url];
                [DatabaseModel fromData:data
                                    ckf:[CompositeKeyFactors password:@"a"]
               useLegacyDeserialization:NO
                             completion:^(BOOL userCancelled, DatabaseModel * _Nonnull model, NSError * _Nonnull error) {
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

@end
