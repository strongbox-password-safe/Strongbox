//
//  PwSafeSerializationTests.m
//  StrongboxTests
//
//  Created by Mark on 23/10/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "PwSafeDatabase.h"

@interface PwSafeSerializationTests : XCTestCase

@end

@implementation PwSafeSerializationTests

- (void)testOpenSimple {
    NSBundle *bundle = [NSBundle bundleForClass:[self class]];
    NSString *path = [bundle pathForResource:@"simple-unit-test-strongbox" ofType:@"dat"];
    NSData* safeData = [NSData dataWithContentsOfFile:path];
    
    id<AbstractDatabaseFormatAdaptor> adaptor = [[PwSafeDatabase alloc] init];
     NSInputStream* stream = [NSInputStream inputStreamWithData:safeData];
     [stream open];
     [adaptor read:stream
              ckf:[CompositeKeyFactors password:@"a"]
       completion:^(BOOL userCancelled, StrongboxDatabase * _Nullable db, NSError * _Nullable error) {
        if(!db) {
            NSLog(@"ERROR: %@", error);
            return;
        }
        
        XCTAssertNotNil(db);
        
        NSLog(@"%@", db);
    }];
}

@end
