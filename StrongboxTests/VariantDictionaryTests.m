//
//  VariantDictionaryTests.m
//  StrongboxTests
//
//  Created by Mark on 05/11/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "VariantDictionary.h"

@interface VariantDictionaryTests : XCTestCase

@end

@implementation VariantDictionaryTests

// Sorted keys important for serialize/deserialize tests as NSDictionary doesn't guarantee order... Variant Dictionary serializes in sorted key order...

static NSString * const b64ExampleWithSortedKeys = @"AAFCBQAAACRVVUlEEAAAAO9jbd+MKURLkfeppAPjCgwFAQAAAEkIAAAAAgAAAAAAAAAFAQAAAE0IAAAAAAAQAAAAAAAEAQAAAFAEAAAAAgAAAEIBAAAAUyAAAAD+9eWPE9YfGcheX/nexGOg9G2/wouoUYcV3prcWTGmpgQBAAAAVgQAAAATAAAAAA==";

- (void)testFromDataExample {
    NSData* data = [[NSData alloc] initWithBase64EncodedString:b64ExampleWithSortedKeys options:kNilOptions];

    NSDictionary* dict = [VariantDictionary fromData:data];

    NSLog(@"%@", dict);
    
    XCTAssert(dict.count == 6);
    
    VariantObject* d = dict[@"$UUID"];
    
    XCTAssert(d);
}

- (void)testToDataExample {
    NSData* data = [[NSData alloc] initWithBase64EncodedString:b64ExampleWithSortedKeys options:kNilOptions];
    
    NSDictionary* dict = [VariantDictionary fromData:data];
    
    NSData* newData = [VariantDictionary toData:dict];

    //NSLog(@"New base64: [%@]", [newData base64EncodedStringWithOptions:kNilOptions]);
    
    XCTAssert([data isEqualToData:newData]);
}

- (void)testBool {
    VariantObject* vt = [[VariantObject alloc] initWithType:kVariantTypeBool theObject:@(YES)];
    VariantObject* vf = [[VariantObject alloc] initWithType:kVariantTypeBool theObject:@(NO)];
    
    NSDictionary* dict = @{ @"True-Key" : vt, @"False-Key" : vf  };
    
    NSData* d = [VariantDictionary toData:dict];

    NSDictionary<NSString*, VariantObject*> *ret = [VariantDictionary fromData:d];

    XCTAssert([ret[@"True-Key"].theObject isEqual:@(YES)]);
    XCTAssert([ret[@"False-Key"].theObject isEqual:@(NO)]);
}

@end
