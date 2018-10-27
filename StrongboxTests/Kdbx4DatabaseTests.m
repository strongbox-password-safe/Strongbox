//
//  Kdbx4DatabaseTests.m
//  StrongboxTests
//
//  Created by Mark on 26/10/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "CommonTesting.h"
#import "Kdbx4Database.h"

@interface Kdbx4DatabaseTests : XCTestCase

@end

@implementation Kdbx4DatabaseTests

- (void)testInitExistingWithAllKdbxTestFiles {
    for (NSString* file in CommonTesting.testKdbx4FilesAndPasswords) {
        NSLog(@"=============================================================================================================");
        NSLog(@"===================================== %@ ===============================================", file);
        
        NSData *blob = [CommonTesting getDataFromBundleFile:file ofType:@"kdbx"];
        
        NSError* error;
        NSString* password = [CommonTesting.testKdbx4FilesAndPasswords objectForKey:file];
        
        Kdbx4Database *db = [[Kdbx4Database alloc] initExistingWithDataAndPassword:blob password:password error:&error];
        
        XCTAssertNotNil(db);
        
        NSLog(@"%@", db);
        NSLog(@"=============================================================================================================");
    }
}

@end
